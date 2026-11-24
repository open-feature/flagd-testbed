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

	if err := writeAndWaitForUpdate(configFile, updatedData); err != nil {
		return "", err
	}
	if err := toggleMetadataChangeFlags(); err != nil {
		return "", err
	}
	return flag.DefaultVariant, nil
}

// toggleMetadataChangeFlags flips the flag set metadata version and the modified flag (default variant and metadata version);
// the overriding and inheriting flags are left untouched
func toggleMetadataChangeFlags() error {
	configFile := "rawflags/selector-metadata-change-flags.json"

	data, err := os.ReadFile(configFile)
	if err != nil {
		return err
	}

	var config map[string]interface{}
	if err := json.Unmarshal(data, &config); err != nil {
		return err
	}

	setMetadata, ok := config["metadata"].(map[string]interface{})
	if !ok {
		return errors.New("flag set metadata not found in configuration")
	}
	flags, ok := config["flags"].(map[string]interface{})
	if !ok {
		return errors.New("flags not found in configuration")
	}
	modifiedFlag, ok := flags["metadata-change-modified-flag"].(map[string]interface{})
	if !ok {
		return errors.New("metadata-change-modified-flag not found in configuration")
	}
	modifiedFlagMetadata, ok := modifiedFlag["metadata"].(map[string]interface{})
	if !ok {
		return errors.New("metadata-change-modified-flag metadata not found in configuration")
	}

	if setMetadata["version"] == "1" {
		setMetadata["version"] = "2"
		modifiedFlag["defaultVariant"] = "bar"
		modifiedFlagMetadata["version"] = "11"
	} else {
		setMetadata["version"] = "1"
		modifiedFlag["defaultVariant"] = "foo"
		modifiedFlagMetadata["version"] = "10"
	}

	updatedData, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return err
	}

	return writeAndWaitForUpdate(configFile, updatedData)
}

// writeAndWaitForUpdate writes the file and blocks until the file watcher has picked it up
func writeAndWaitForUpdate(configFile string, updatedData []byte) error {
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

	fileLock.Lock()
	if err := atomicWriteFile(configFile, updatedData); err != nil {
		fileLock.Unlock()
		return err
	}
	fileLock.Unlock()

	<-ctx.Done()
	if errors.Is(ctx.Err(), context.DeadlineExceeded) {
		return fmt.Errorf("Flags were not updated in time: %v", ctx.Err())
	}
	return nil
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
					if strings.HasSuffix(event.Name, "changing-flag.json") || strings.HasSuffix(event.Name, "metadata-change-flags.json") {
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
