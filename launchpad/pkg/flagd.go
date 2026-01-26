package flagd

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"sync"
	"time"
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

	// Poll health endpoint until ready
	client := &http.Client{Timeout: 500 * time.Millisecond}
	deadline := time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) {
		resp, err := client.Get("http://localhost:8014/readyz")
		if err == nil {
			resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				fmt.Println("flagd started successfully.")
				return nil
			}
		}
		time.Sleep(100 * time.Millisecond)
	}

	_ = StopFlagd()
	return fmt.Errorf("flagd health check timed out")
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
