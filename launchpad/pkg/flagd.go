package flagd

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

const (
	variantBudget      = 10 * time.Second
	servedPollInterval = 10 * time.Millisecond
	probeTimeout       = 500 * time.Millisecond

	readyzURL = "http://localhost:8014/readyz"
	// OFREP is plain HTTP in every config, including the TLS one.
	ofrepEvaluateURL = "http://localhost:8016/ofrep/v1/evaluate/flags/"
)

var (
	flagdCmd              *exec.Cmd
	flagdLock             sync.Mutex
	Config                = "default"
	DefaultRestartTimeout = 5
	restartCancelFunc     context.CancelFunc // Stores the cancel function for delayed restarts
)

func ensureStartConditions() {
	if _, err := os.Stat(OutputFile); errors.Is(err, os.ErrNotExist) {
		err := CombineJSONFiles(InputDir)
		if err != nil {
			fmt.Printf("Error combining JSON files on flagd start: %v\n", err)
		}
	}
	if err := RestartFileWatcher(); err != nil {
		fmt.Printf("error restarting file watcher: %v\n", err)
	}
}

func deleteCombinedFlagsFile() {
	// if we cannot delete it, we can assume it did not exist in the first place, so we can ignore this error
	_ = os.Remove(OutputFile)
}

func RestartFlagd(seconds int) {
	flagdLock.Lock()
	if restartCancelFunc != nil {
		restartCancelFunc()
		fmt.Println("Previous restart canceled.")
	}

	ctx, cancel := context.WithCancel(context.Background())
	restartCancelFunc = cancel

	deleteCombinedFlagsFile()
	err := stopFlagDWithoutLock()
	if err != nil {
		fmt.Printf("Failed to restart flagd: %v\n", err)
	}
	flagdLock.Unlock()

	go func() {
		fmt.Printf("flagd will restart in %d seconds...\n", seconds)
		select {
		case <-time.After(time.Duration(seconds) * time.Second):
			fmt.Println("Restarting flagd now...")
			if err := StartFlagd(Config); err != nil {
				fmt.Printf("Failed to restart flagd: %v\n", err)
			} else {
				fmt.Println("flagd restarted successfully.")
			}
		case <-ctx.Done():
			fmt.Println("Restart canceled before execution.")
		}
	}()
}

func StartFlagd(config string) error {
	flagdLock.Lock()

	if config == "" {
		config = Config
	}

	// Reuse the running flagd if it has the requested config and still answers;
	// Process stays non-nil after a crash, hence the readiness probe.
	reuse := flagdCmd != nil && flagdCmd.Process != nil &&
		restartCancelFunc == nil && config == Config && isReady()

	Config = config

	// Cancel any pending restart attempts
	if restartCancelFunc != nil {
		restartCancelFunc()
		fmt.Println("Pending restart canceled due to manual start.")
		restartCancelFunc = nil
	}

	configPath := flagdConfigPath(config)

	if reuse {
		// The restore runs unlocked; a concurrent /stop or /restart is not
		// guarded against, harnesses call these sequentially.
		flagdLock.Unlock()
		return resumeRunningFlagd()
	}

	if err := stopFlagDWithoutLock(); err != nil {
		flagdLock.Unlock()
		return err
	}

	ensureStartConditions()

	flagdCmd = exec.Command("./flagd", "start", "--config", configPath)
	flagdCmd.Stdout = os.Stdout
	flagdCmd.Stderr = os.Stderr

	if err := flagdCmd.Start(); err != nil {
		flagdLock.Unlock()
		return fmt.Errorf("failed to start flagd: %v", err)
	}
	flagdLock.Unlock()

	// Poll health endpoint until ready
	client := &http.Client{Timeout: 500 * time.Millisecond}
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()
	timeout := time.After(10 * time.Second)

	for {
		select {
		case <-timeout:
			_ = StopFlagd()
			return fmt.Errorf("flagd health check timed out")
		case <-ticker.C:
			resp, err := client.Get(readyzURL)
			if err == nil {
				resp.Body.Close()
				if resp.StatusCode == http.StatusOK {
					fmt.Println("flagd started successfully.")
					return nil
				}
			}
		}
	}
}

func flagdConfigPath(config string) string {
	return fmt.Sprintf("./configs/%s.json", config)
}

// resumeRunningFlagd restores the baseline flag state instead of restarting flagd.
func resumeRunningFlagd() error {
	restored, err := RestoreChangingFlag()
	if err != nil {
		return fmt.Errorf("failed to restore the baseline flag state: %w", err)
	}

	if !restored {
		fmt.Println("flagd reused; baseline flag state already in force.")
		return nil
	}

	fmt.Println("flagd reused; baseline flag state restored.")
	return nil
}

// awaitVariantInFlagd waits until flagd serves changing-flag as variant. Configs
// that do not read the merged flag file can never serve it, so they are skipped.
func awaitVariantInFlagd(variant string) error {
	if !flagdIsRunning() {
		return nil
	}
	if !servesCombinedFlags(flagdConfigPath(Config)) {
		return nil
	}

	ctx, cancel := context.WithTimeout(context.Background(), variantBudget)
	defer cancel()

	return awaitVariantServed(ctx, &http.Client{Timeout: probeTimeout}, ChangingFlagKey, variant)
}

func flagdIsRunning() bool {
	flagdLock.Lock()
	defer flagdLock.Unlock()

	return flagdCmd != nil && flagdCmd.Process != nil
}

func isReady() bool {
	resp, err := (&http.Client{Timeout: probeTimeout}).Get(readyzURL)
	if err != nil {
		return false
	}
	resp.Body.Close()
	return resp.StatusCode == http.StatusOK
}

func awaitVariantServed(ctx context.Context, client *http.Client, key, variant string) error {
	ticker := time.NewTicker(servedPollInterval)
	defer ticker.Stop()

	for {
		if servedVariant(ctx, client, key) == variant {
			return nil
		}
		select {
		case <-ctx.Done():
			return fmt.Errorf("flagd did not serve %q as variant %q before the budget expired", key, variant)
		case <-ticker.C:
		}
	}
}

func servedVariant(ctx context.Context, client *http.Client, key string) string {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, ofrepEvaluateURL+url.PathEscape(key), strings.NewReader("{}"))
	if err != nil {
		return ""
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return ""
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return ""
	}

	var evaluation struct {
		Variant string `json:"variant"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&evaluation); err != nil {
		return ""
	}
	return evaluation.Variant
}

func servesCombinedFlags(configPath string) bool {
	sources, err := fileSources(configPath)
	if err != nil {
		fmt.Printf("Cannot tell whether %s serves the merged flag file: %v\n", configPath, err)
		return false
	}

	for _, uri := range sources {
		if filepath.Clean(uri) == filepath.Clean(OutputFile) {
			return true
		}
	}
	return false
}

func fileSources(configPath string) ([]string, error) {
	content, err := os.ReadFile(configPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read flagd config: %w", err)
	}

	var cfg struct {
		Sources []struct {
			URI      string `json:"uri"`
			Provider string `json:"provider"`
		} `json:"sources"`
	}
	if err := json.Unmarshal(content, &cfg); err != nil {
		return nil, fmt.Errorf("failed to parse flagd config: %w", err)
	}

	var uris []string
	for _, source := range cfg.Sources {
		if source.Provider != "file" {
			continue
		}
		uris = append(uris, source.URI)
	}
	return uris, nil
}

func StopFlagd() error {
	flagdLock.Lock()
	defer flagdLock.Unlock()

	// Cancel any pending restart attempts
	if restartCancelFunc != nil {
		restartCancelFunc()
		fmt.Println("Pending restart canceled due to manual start.")
		restartCancelFunc = nil
	}

	err := stopFlagDWithoutLock()
	if err != nil {
		return err
	}

	return nil
}

func stopFlagDWithoutLock() error {
	if flagdCmd != nil && flagdCmd.Process != nil {
		if err := flagdCmd.Process.Kill(); err != nil {
			return fmt.Errorf("failed to stop flagd: %v", err)
		}

		// Wait for the process to fully terminate with a timeout
		done := make(chan error, 1)
		go func() {
			done <- flagdCmd.Wait()
		}()

		select {
		case <-done:
			// Process fully terminated
		case <-time.After(5 * time.Second):
			fmt.Println("Warning: timeout waiting for flagd process to terminate")
		}

		flagdCmd = nil
		fmt.Println("flagd stopped")
	}
	return nil
}
