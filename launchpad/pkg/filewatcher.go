package flagd

import (
	"fmt"
	"github.com/fsnotify/fsnotify"
	"strings"
	"sync"
)

var changeFlagLock sync.Mutex

func StartFileWatcher() error {
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		return fmt.Errorf("failed to create file watcher: %v", err)
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
					}
					if strings.HasSuffix(event.Name, "changing-flag.json") {
						changeFlagLock.Lock()
						for _, v := range changeFlagUpdateListeners {
							v.Done()
						}
						changeFlagUpdateListeners = nil
						changeFlagLock.Unlock()
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

var changeFlagUpdateListeners []*sync.WaitGroup

// RegisterWaitForNextChangingFlagUpdate
// The waitGroup passed to this function will be invoked when a file update to the changing-flag.json file is detected.
// After such an invocation, it will be removed and will not be called on subsequent updates to the	file.
func RegisterWaitForNextChangingFlagUpdate(waitGroup *sync.WaitGroup) {
	changeFlagLock.Lock()
	defer changeFlagLock.Unlock()
	changeFlagUpdateListeners = append(changeFlagUpdateListeners, waitGroup)
}
