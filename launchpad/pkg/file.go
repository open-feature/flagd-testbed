package flagd

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/fsnotify/fsnotify"
)

type FlagConfig struct {
	Flags map[string]struct {
		State          string            `json:"state"`
		Variants       map[string]string `json:"variants"`
		DefaultVariant string            `json:"defaultVariant"`
	} `json:"flags"`
}

var (
	fileLock                  sync.Mutex // lock for file operations
	changeLock                sync.Mutex // lock for change requests (so that multiple requests don't overlap)
	watcher                   *fsnotify.Watcher
	changeFlagUpdateListeners []*sync.WaitGroup
)

func ToggleChangingFlag() (string, error) {
	changeLock.Lock()
	defer changeLock.Unlock()

	// Path to the configuration file
	configFile := "rawflags/changing-flag.json"

	// Read the existing file
	data, err := os.ReadFile(configFile)
	if err != nil {
		return "", err
	}

	// Parse the JSON into the FlagConfig struct
	var config FlagConfig
	if err := json.Unmarshal(data, &config); err != nil {
		return "", err
	}

	// Find the "changing-flag" and toggle the default variant
	flag, exists := config.Flags["changing-flag"]
	if !exists {
		return "", errors.New("changing-flag not found in configuration")
	}

	// Toggle the defaultVariant between "foo" and "bar"
	if flag.DefaultVariant == "foo" {
		flag.DefaultVariant = "bar"
	} else {
		flag.DefaultVariant = "foo"
	}

	// Save the updated flag back to the configuration
	config.Flags["changing-flag"] = flag
	// Serialize the updated configuration back to JSON
	updatedData, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return "", err
	}

	// the file watcher should be triggered instantly. If not, we add a timeout to prevent a hanging test
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(DefaultRestartTimeout)*time.Second)
	defer cancel()

	// wait for the filewatcher to register an update and write the new json file
	flagUpdateWait := sync.WaitGroup{}
	flagUpdateWait.Add(1)
	changeFlagUpdateListeners = append(changeFlagUpdateListeners, &flagUpdateWait)

	fmt.Println("Waiting for flag update...")

	go func() {
		flagUpdateWait.Wait()
		cancel()
	}()

	// Write the updated JSON back to the file
	fileLock.Lock()
	if err := os.WriteFile(configFile, updatedData, 0644); err != nil {
		return "", err
	}
	fileLock.Unlock()

	select {
	case <-ctx.Done():
		if errors.Is(ctx.Err(), context.DeadlineExceeded) {
			return "", fmt.Errorf("Flags were not updated in time: %v", ctx.Err())
		} else {
			return flag.DefaultVariant, nil
		}
	}
}

func RestartFileWatcher() error {
	fileLock.Lock()
	// grab old watcher while holding lock
	oldWatcher := watcher

	// create new watcher
	var err error
	watcher, err = fsnotify.NewWatcher()
	if err != nil {
		fileLock.Unlock()
		return fmt.Errorf("failed to create file watcher: %v", err)
	}
	changeFlagUpdateListeners = []*sync.WaitGroup{}
	fileLock.Unlock()

	if oldWatcher != nil {
		oldWatcher.Close()
	}

	go func() {
		defer watcher.Close()
		for {
			select {
			case event, ok := <-watcher.Events:
				if !ok {
					return
				}
				if event.Op&(fsnotify.Create|fsnotify.Write|fsnotify.Remove) != 0 {
					fmt.Printf("%v config changed, regenerating JSON...\n", event.Name)
					if err := CombineJSONFiles(InputDir); err != nil {
						fmt.Printf("Error combining JSON files: %v\n", err)
						return
					}
					if strings.HasSuffix(event.Name, "changing-flag.json") {
						for _, v := range changeFlagUpdateListeners {
							v.Done()
						}
						changeFlagUpdateListeners = nil
					}
				}
			case err, ok := <-watcher.Errors:
				if !ok {
					return
				}
				fmt.Printf("File watcher error: %v\n", err)
			}
		}
	}()

	if err := watcher.Add("./rawflags"); err != nil {
		return fmt.Errorf("failed to watch input directory: %v", err)
	}

	fmt.Println("File watcher started.")
	return nil
}
