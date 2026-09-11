package flagd

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"sort"
	"strings"
	"sync"
	"time"
)

const (
	// startupBudget bounds the whole of /start: waiting for the readiness
	// probe and waiting for the flags to actually be served.
	startupBudget = 10 * time.Second

	readyPollInterval  = 100 * time.Millisecond
	servedPollInterval = 10 * time.Millisecond

	readyzURL = "http://localhost:8014/readyz"
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
	if config == "" {
		config = Config
	} else {
		Config = config
	}

	flagdLock.Lock()
	// Cancel any pending restart attempts
	if restartCancelFunc != nil {
		restartCancelFunc()
		fmt.Println("Pending restart canceled due to manual start.")
		restartCancelFunc = nil
	}

	if err := stopFlagDWithoutLock(); err != nil {
		return err
	}

	ensureStartConditions()

	configPath := fmt.Sprintf("./configs/%s.json", config)

	flagdCmd = exec.Command("./flagd", "start", "--config", configPath)
	flagdCmd.Stdout = os.Stdout
	flagdCmd.Stderr = os.Stderr

	if err := flagdCmd.Start(); err != nil {
		flagdLock.Unlock()
		return fmt.Errorf("failed to start flagd: %v", err)
	}
	flagdLock.Unlock()

	client := &http.Client{Timeout: 500 * time.Millisecond}

	// Every probe below runs against this context, so the budget bounds the
	// requests themselves and not just the gaps between them: a probe issued
	// just short of the deadline cannot stretch /start by its own timeout.
	ctx, cancel := context.WithTimeout(context.Background(), startupBudget)
	defer cancel()

	if err := awaitReadyz(ctx, client); err != nil {
		_ = StopFlagd()
		return err
	}

	// /readyz reports ready as soon as every sync source has handed its payload
	// over; flagd parses it and swaps its flag store afterwards, on a separate
	// goroutine. In that window flagd answers FLAG_NOT_FOUND for flags the
	// configuration plainly defines. A provider that blocks during its own
	// initialisation absorbs the window, but a stateless one evaluates the
	// instant /start returns and races it, so wait for a real evaluation.
	if err := awaitFlagsServed(ctx, client, configPath); err != nil {
		_ = StopFlagd()
		return err
	}

	fmt.Println("flagd started successfully.")
	return nil
}

// awaitReadyz waits for flagd's readiness probe to report that every sync
// source has completed at least one successful data sync.
func awaitReadyz(ctx context.Context, client *http.Client) error {
	ticker := time.NewTicker(readyPollInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return fmt.Errorf("flagd health check timed out")
		case <-ticker.C:
			if isReady(ctx, client) {
				return nil
			}
		}
	}
}

// isReady reports whether flagd's readiness probe answers 200.
func isReady(ctx context.Context, client *http.Client) bool {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, readyzURL, nil)
	if err != nil {
		return false
	}

	resp, err := client.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()

	return resp.StatusCode == http.StatusOK
}

// awaitFlagsServed waits until flagd actually resolves a flag from every file
// source the configuration lists, so that a successful /start is a promise
// that the next evaluation resolves against the new baseline.
func awaitFlagsServed(ctx context.Context, client *http.Client, configPath string) error {
	keys, err := probeKeys(configPath)
	if err != nil {
		// Without a probe key there is nothing to verify the store with. Fall
		// back to the readiness probe alone rather than failing a start that
		// would otherwise have worked.
		fmt.Printf("Cannot verify that flags are served for %s, falling back to the readiness probe: %v\n", configPath, err)
		return nil
	}

	for _, key := range keys {
		if err := awaitFlagServed(ctx, client, key); err != nil {
			return err
		}
	}
	return nil
}

func awaitFlagServed(ctx context.Context, client *http.Client, key string) error {
	ticker := time.NewTicker(servedPollInterval)
	defer ticker.Stop()

	for {
		if flagIsServed(ctx, client, key) {
			return nil
		}
		select {
		case <-ctx.Done():
			return fmt.Errorf("flagd did not serve flag %q before the startup budget expired", key)
		case <-ticker.C:
		}
	}
}

// flagIsServed reports whether flagd holds the given flag in its store. flagd
// answers FLAG_NOT_FOUND both while the store is still empty and for a key it
// genuinely does not hold. A 5xx is not an evaluation at all - flagd is telling
// us it could not answer - so it says nothing about the store and is worth
// another poll. Every other answer means flagd resolved the key against a
// populated store, including a 4xx for a flag whose targeting cannot be
// satisfied from the empty context we send.
func flagIsServed(ctx context.Context, client *http.Client, key string) bool {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, ofrepEvaluateURL+url.PathEscape(key), strings.NewReader("{}"))
	if err != nil {
		return false
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()

	if resp.StatusCode >= http.StatusInternalServerError {
		return false
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return false
	}
	return !bytes.Contains(body, []byte("FLAG_NOT_FOUND"))
}

// probeKeys returns one enabled flag key per file source of the given flagd
// configuration. Deriving the keys from the configuration rather than hard
// coding one keeps the check working for every configuration we ship, and
// covers each source separately because they are merged into the store
// independently.
func probeKeys(configPath string) ([]string, error) {
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

	var keys []string
	for _, source := range cfg.Sources {
		if source.Provider != "file" {
			continue
		}
		key, err := enabledFlagKey(source.URI)
		if err != nil {
			return nil, err
		}
		keys = append(keys, key)
	}

	if len(keys) == 0 {
		return nil, fmt.Errorf("no file source with an enabled flag found")
	}
	return keys, nil
}

// enabledFlagKey picks a stable, enabled flag key from a flag definition file.
// Disabled flags are skipped because flagd reports FLAG_NOT_FOUND for them,
// which would be indistinguishable from the store not being populated yet.
func enabledFlagKey(path string) (string, error) {
	content, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("failed to read flag source %s: %w", path, err)
	}

	var definition struct {
		Flags map[string]struct {
			State string `json:"state"`
		} `json:"flags"`
	}
	if err := json.Unmarshal(content, &definition); err != nil {
		return "", fmt.Errorf("failed to parse flag source %s: %w", path, err)
	}

	candidates := make([]string, 0, len(definition.Flags))
	for key, flag := range definition.Flags {
		if flag.State == "DISABLED" {
			continue
		}
		candidates = append(candidates, key)
	}
	if len(candidates) == 0 {
		return "", fmt.Errorf("flag source %s defines no enabled flag", path)
	}

	sort.Strings(candidates)
	return candidates[0], nil
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
