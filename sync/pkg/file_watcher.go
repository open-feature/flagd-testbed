package sync

import (
	"encoding/json"
	"github.com/fsnotify/fsnotify"
	"golang.org/x/exp/maps"
	"log"
	"os"
	"sync"
	"time"
)

// fileWatcher watches given file paths for updates and allow subscriptions for updates
type fileWatcher struct {
	data  []byte
	paths []string
	subs  map[interface{}]chan<- []byte
	mu    sync.Mutex
}

func (w *fileWatcher) init() error {
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		return err
	}

	for _, filePath := range w.paths {
		err := watcher.Add(filePath)
		if err != nil {
			log.Printf("Error watching file %s, caused by %s\n", filePath, err.Error())
			return err
		}
	}

	// initial read & store
	w.data, err = readFlags(w.paths)
	if err != nil {
		log.Printf("Error reading flag data: %v\n", err)
		return err
	}

	// run watcher in background
	go func() {
		// Start listening for file events.
		for {
			select {
			case event, ok := <-watcher.Events:
				if !ok {
					log.Println("Unable to process file event, continuing")
					continue
				}

				if event.Has(fsnotify.Write) {
					marshalled, err := readFlags(w.paths)
					if err != nil {
						log.Printf("Error reading flags: %s, continuing \n", err.Error())
						continue
					}

					// store latest
					w.updateData(marshalled)
				}
			case err := <-watcher.Errors:
				log.Printf("Error in file watcher: %s, exiting watcher\n", err.Error())
				return
			}
		}
	}()

	return nil
}

func (w *fileWatcher) getCurrentData() []byte {
	w.mu.Lock()
	defer w.mu.Unlock()

	return w.data
}

func (w *fileWatcher) updateData(data []byte) {
	w.mu.Lock()
	defer w.mu.Unlock()

	w.data = data

	// push to subs
	for _, v := range w.subs {
		v <- w.data
	}
}

func (w *fileWatcher) subscribe(channel chan<- []byte) {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.subs[channel] = channel
}

func (w *fileWatcher) unSubscribe(channel chan<- []byte) {
	w.mu.Lock()
	defer w.mu.Unlock()

	delete(w.subs, channel)
}

// readFlags is a helper to read given files and combine flags in them
func readFlags(filePaths []string) ([]byte, error) {
	flags := make(map[string]any)
	evaluators := make(map[string]any)

	for _, path := range filePaths {
		bytes, err := os.ReadFile(path)
		if err != nil {
			log.Printf("File read error %s\n", err.Error())
			return nil, err
		}

		for len(bytes) == 0 {
			// this is a fitly hack
			// file writes are NOT atomic and often when they are occur they have transitional empty states
			// this "re-reads" the file in these cases a bit later
			log.Printf("File content not ready for %s, busy wait\n", path)
			time.Sleep(100 * time.Millisecond)
			bytes, err = os.ReadFile(path)
			if err != nil {
				log.Printf("File read error %s\n", err.Error())
				return nil, err
			}
		}
		parsed := make(map[string]map[string]any)
		err = json.Unmarshal(bytes, &parsed)
		if err != nil {
			log.Printf("JSON unmarshal error %s\n", err.Error())
			return nil, err
		}
		maps.Copy(flags, parsed["flags"])
		maps.Copy(evaluators, parsed["$evaluators"])
	}

	payload := make(map[string]any)
	payload["flags"] = flags
	payload["$evaluators"] = evaluators
	marshalled, err := json.Marshal(payload)
	if err != nil {
		log.Printf("JSON marshal error %s\n", err.Error())
		return nil, err
	}

	log.Println("Update complete")
	return marshalled, nil
}
