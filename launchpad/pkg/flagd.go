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
	// variantBudget bounds how long a restore waits for flagd to serve the
	// restored variant.
	variantBudget = 10 * time.Second

	servedPollInterval = 10 * time.Millisecond

	// probeTimeout bounds a single probe request. variantBudget bounds the
	// sequence of them.
	probeTimeout = 500 * time.Millisecond

	// flagd serves OFREP over plain HTTP on 8016 for every configuration we
	// ship, including the one that configures server certificates (those apply
	// to the flag evaluation port only), so one URL works for all of them.
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

	// The running process is only reusable if it is the one that would be
	// started anyway: same configuration, still alive, and not inside a delayed
	// restart's downtime window. A pending restart implies flagd is already
	// stopped, so the process check covers it, but saying so is cheaper than
	// relying on that.
	reuse := flagdCmd != nil && flagdCmd.Process != nil &&
		restartCancelFunc == nil && config == Config

	Config = config

	// Cancel any pending restart attempts
	if restartCancelFunc != nil {
		restartCancelFunc()
		fmt.Println("Pending restart canceled due to manual start.")
		restartCancelFunc = nil
	}

	configPath := flagdConfigPath(config)

	if reuse {
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
			resp, err := client.Get("http://localhost:8014/readyz")
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

// resumeRunningFlagd restores the baseline flag state in the flagd that is
// already running, instead of restarting it.
//
// Restarting is how /start achieves isolation today, and for a client that has
// no /reset to call it is the only way to get it - which means a full flagd
// restart before every scenario, for a configuration that has not changed. The
// process is not what carries the scenario's leftovers; the flag definitions
// are. Putting those back is enough, and it is what the existing file watcher
// is already there to deliver.
func resumeRunningFlagd() error {
	restored, err := RestoreChangingFlag()
	if err != nil {
		return fmt.Errorf("failed to restore the baseline flag state: %w", err)
	}

	if !restored {
		// Nothing has mutated a flag definition since the last restore, so the
		// running flagd is already serving the baseline. Most scenarios never
		// call /change, which makes this the common case and a free one.
		fmt.Println("flagd reused; baseline flag state already in force.")
		return nil
	}

	// RestoreChangingFlag does not return until flagd serves the restored
	// variant, so there is nothing left to wait for here.
	fmt.Println("flagd reused; baseline flag state restored.")
	return nil
}

// awaitVariantInFlagd waits until the running flagd resolves changing-flag to
// the given variant.
//
// There is nothing to wait for when flagd is not running, or when the running
// configuration does not read the merged flag file - that file is the only
// source changing-flag reaches flagd through, so a configuration without it can
// never serve the flag and polling for it would burn the whole budget before
// failing.
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

// awaitVariantServed waits until flagd resolves key to the given variant.
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

// servedVariant reports the variant flagd currently resolves key to, and an
// empty string for any answer that is not a successful evaluation.
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

// servesCombinedFlags reports whether the configuration reads the merged flag
// file that changing-flag reaches flagd through.
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

// fileSources returns the URIs of every file source the given flagd
// configuration reads.
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
