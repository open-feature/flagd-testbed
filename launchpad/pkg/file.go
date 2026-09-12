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

const (
	// ChangingFlagFile is the only flag definition the launchpad ever writes to,
	// and changing-flag is the only flag in it. Keeping that true is what lets
	// the baseline be restored without a pristine copy of the definitions - see
	// RestoreChangingFlag.
	ChangingFlagFile = "rawflags/changing-flag.json"
	// ChangingFlagKey is the flag /change toggles.
	ChangingFlagKey = "changing-flag"
	// BaselineChangingVariant is the defaultVariant changing-flag ships with.
	BaselineChangingVariant = "foo"
	// toggledChangingVariant is the other half of the toggle.
	toggledChangingVariant = "bar"
)

var (
	fileLock                  sync.Mutex // lock for file operations
	changeLock                sync.Mutex // lock for change requests (so that multiple requests don't overlap)
	watcher                   *fsnotify.Watcher
	changeFlagUpdateListeners []*sync.WaitGroup
)

// ToggleChangingFlag flips changing-flag to its other variant and reports the
// one now in force.
func ToggleChangingFlag() (string, error) {
	changeLock.Lock()
	defer changeLock.Unlock()

	current, err := readChangingVariant()
	if err != nil {
		return "", err
	}

	next := BaselineChangingVariant
	if current == BaselineChangingVariant {
		next = toggledChangingVariant
	}

	return next, writeChangingVariant(next)
}

// RestoreChangingFlag puts changing-flag back to the variant it ships with and
// reports whether it had to write anything.
//
// /change is the only endpoint that mutates a flag definition, and it mutates
// exactly one flag with exactly two states, so the shipped baseline is
// recoverable by flipping the toggle back rather than by restoring from a
// pristine copy of the definitions - which the image does not carry, because
// /change overwrites its own source in the container's writable layer.
//
// The current variant is read rather than remembered on purpose. A launchpad
// that restarts inside a container whose writable layer already holds "bar"
// would believe a remembered flag, and go on serving "bar" while reporting a
// restored baseline. Reading it is also what makes the common case free: most
// scenarios never call /change, so most restores write nothing at all.
//
// Reading it is only sound because every write waits for flagd to serve what it
// wrote - see writeChangingVariant. Without that, a file already reading "foo"
// could not be told apart from a flagd that has not caught up with it yet.
func RestoreChangingFlag() (bool, error) {
	changeLock.Lock()
	defer changeLock.Unlock()

	current, err := readChangingVariant()
	if err != nil {
		return false, err
	}
	if current == BaselineChangingVariant {
		return false, nil
	}

	return true, writeChangingVariant(BaselineChangingVariant)
}

// readChangingVariant reports the defaultVariant currently written to
// changing-flag's definition.
func readChangingVariant() (string, error) {
	data, err := os.ReadFile(ChangingFlagFile)
	if err != nil {
		return "", err
	}

	var config FlagConfig
	if err := json.Unmarshal(data, &config); err != nil {
		return "", err
	}

	flag, exists := config.Flags[ChangingFlagKey]
	if !exists {
		return "", errors.New("changing-flag not found in configuration")
	}
	return flag.DefaultVariant, nil
}

// writeChangingVariant sets changing-flag's defaultVariant and does not return
// until flagd serves it.
//
// Two watchers stand between the write and the served value: ours, which
// regenerates the merged flag file, and flagd's, which re-reads it. Waiting on
// ours alone used to be the whole of this function, and it is not enough -
// measured against v0.16.0, flagd serves the new variant around 500ms after
// /change has reported success.
//
// Waiting for both is what lets the current file content be read as the state
// flagd is in, which is the invariant RestoreChangingFlag depends on: if the
// file says "foo", flagd is serving "foo", so there is nothing to restore.
func writeChangingVariant(variant string) error {
	// Read the existing file
	data, err := os.ReadFile(ChangingFlagFile)
	if err != nil {
		return err
	}

	// Parse the JSON into the FlagConfig struct
	var config FlagConfig
	if err := json.Unmarshal(data, &config); err != nil {
		return err
	}

	// Find the "changing-flag" and set the default variant
	flag, exists := config.Flags[ChangingFlagKey]
	if !exists {
		return errors.New("changing-flag not found in configuration")
	}
	flag.DefaultVariant = variant

	// Save the updated flag back to the configuration
	config.Flags[ChangingFlagKey] = flag
	// Serialize the updated configuration back to JSON
	updatedData, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return err
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
	if err := atomicWriteFile(ChangingFlagFile, updatedData); err != nil {
		fileLock.Unlock()
		return err
	}
	fileLock.Unlock()

	<-ctx.Done()
	if errors.Is(ctx.Err(), context.DeadlineExceeded) {
		return fmt.Errorf("flags were not updated in time: %v", ctx.Err())
	}

	return awaitVariantInFlagd(variant)
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
