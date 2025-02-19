package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/fsnotify/fsnotify"
)

var (
	flagdCmd      *exec.Cmd
	flagdLock     sync.Mutex
	currentConfig = "default" // Default fallback configuration
	inputDir      = "./rawflags"
	outputDir     = "./flags"
	outputFile    = filepath.Join(outputDir, "allFlags.json")
)

func stopFlagd() error {
	flagdLock.Lock()
	defer flagdLock.Unlock()

	if flagdCmd != nil && flagdCmd.Process != nil {
		if err := flagdCmd.Process.Kill(); err != nil {
			return fmt.Errorf("failed to stop flagd: %v", err)
		}
		flagdCmd = nil
	}
	return nil
}

func startFlagdHandler(w http.ResponseWriter, r *http.Request) {
	config := r.URL.Query().Get("config")
	err := startFlagd(config)
	if err != nil {
		http.Error(w, "Failed to start flagd: "+err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	w.Write([]byte(fmt.Sprintf("flagd started with config: %s", config)))
}

func startFlagd(config string) error {
	if config == "" {
		config = currentConfig // Use the last configuration or "default"
	} else {
		currentConfig = config // Update the current configuration
	}

	flagdLock.Lock()
	// Stop any currently running flagd instance
	if err := stopFlagd(); err != nil {
		return err
	}

	configPath := "./configs/" + config + ".json"

	// Start a new instance
	flagdCmd = exec.Command("./flagd", "start", "--config", configPath)
	flagdLock.Unlock() // 🔥 Unlock before logs start
	// Set up the output of flagd to be printed to the current terminal (stdout)

	// Capture stdout and stderr separately
	stdout, err := flagdCmd.StdoutPipe()
	if err != nil {
		return fmt.Errorf("failed to capture stdout: %v", err)
	}
	stderr, err := flagdCmd.StderrPipe()
	if err != nil {
		return fmt.Errorf("failed to capture stderr: %v", err)
	}
	// Start the process
	if err := flagdCmd.Start(); err != nil {
		return fmt.Errorf("failed to start flagd: %v", err)
	}
	// Create channels to signal readiness
	ready := make(chan bool)

	// Monitor stdout and stderr for a readiness signal
	go func() {
		scannerOut := bufio.NewScanner(stdout)
		for scannerOut.Scan() {
			fmt.Println("[flagd stdout]:", scannerOut.Text())
		}
	}()

	go func() {
		scannerErr := bufio.NewScanner(stderr)
		for scannerErr.Scan() {
			fmt.Println("[flagd stderr]:", scannerErr.Text())
			line := scannerErr.Text()
			fmt.Println("[flagd stderr]:", line)
			if strings.Contains(line, "listening at") {
				ready <- true
				return
			}
		}
	}()

	// Wait for flagd to print the expected log or timeout
	select {
	case success := <-ready:
		if success {
			fmt.Println("flagd started successfully.")
			return nil
		}
		return fmt.Errorf("flagd did not start correctly")
	case <-time.After(10 * time.Second): // Timeout
		err := stopFlagd()
		if err != nil {
			fmt.Println(err)
		}
		return fmt.Errorf("flagd start timeout exceeded")
	}
}

func stopFlagdHandler(w http.ResponseWriter, r *http.Request) {
	if err := stopFlagd(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("flagd stopped"))
	log.Println("stopped flagd with config ", currentConfig)
}

type FlagConfig struct {
	Flags map[string]struct {
		State          string            `json:"state"`
		Variants       map[string]string `json:"variants"`
		DefaultVariant string            `json:"defaultVariant"`
	} `json:"flags"`
}

func restartHandler(w http.ResponseWriter, r *http.Request) {
	// Parse the "seconds" query parameter
	secondsStr := r.URL.Query().Get("seconds")
	if secondsStr == "" {
		secondsStr = "5"
	}

	seconds, err := strconv.Atoi(secondsStr)
	if err != nil || seconds < 0 {
		http.Error(w, "'seconds' must be a non-negative integer", http.StatusBadRequest)
		return
	}

	fmt.Println("flagd will be stopped for restart\n")
	// Stop flagd
	if err := stopFlagd(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to stop flagd: %v", err), http.StatusInternalServerError)
		return
	}

	err = os.Remove(outputFile)
	if err != nil {
		fmt.Printf("failed to remove file - %v", err)
	}

	fmt.Fprintf(w, "flagd will restart in %d seconds...\n", seconds)

	// Restart flagd after the specified delay
	go func(delay int) {
		time.Sleep(time.Duration(delay) * time.Second)
		// Initialize the combined JSON file on startup
		if err := CombineJSONFiles(); err != nil {
			fmt.Printf("Error during initial JSON combination: %v\n", err)
			os.Exit(1)
		}

		if err := startFlagd(currentConfig); err != nil {
			fmt.Printf("Failed to restart flagd: %v\n", err)
		} else {
			fmt.Println("flagd restarted successfully.")
		}
	}(seconds)
}

var mu sync.Mutex // Mutex to ensure thread-safe file operations

func changeHandler(w http.ResponseWriter, r *http.Request) {
	mu.Lock() // Lock to ensure only one operation happens at a time
	defer mu.Unlock()

	// Path to the configuration file
	configFile := filepath.Join(inputDir, "changing-flag.json")

	// Read the existing file
	data, err := os.ReadFile(configFile)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to read file: %v", err), http.StatusInternalServerError)
		return
	}

	// Parse the JSON into the FlagConfig struct
	var config FlagConfig
	if err := json.Unmarshal(data, &config); err != nil {
		http.Error(w, fmt.Sprintf("Failed to parse JSON: %v", err), http.StatusInternalServerError)
		return
	}

	// Find the "changing-flag" and toggle the default variant
	flag, exists := config.Flags["changing-flag"]
	if !exists {
		http.Error(w, "Flag 'changing-flag' not found in the configuration", http.StatusNotFound)
		return
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
		http.Error(w, fmt.Sprintf("Failed to serialize updated JSON: %v", err), http.StatusInternalServerError)
		return
	}

	// Write the updated JSON back to the file
	if err := os.WriteFile(configFile, updatedData, 0644); err != nil {
		http.Error(w, fmt.Sprintf("Failed to write updated file: %v", err), http.StatusInternalServerError)
		return
	}

	// Respond to the client with success
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, "Default variant successfully changed to '%s'\n", flag.DefaultVariant)
}

func deepMerge(dst, src map[string]interface{}) map[string]interface{} {
	for key, srcValue := range src {
		if dstValue, exists := dst[key]; exists {
			// If both values are maps, merge recursively
			if srcMap, ok := srcValue.(map[string]interface{}); ok {
				if dstMap, ok := dstValue.(map[string]interface{}); ok {
					dst[key] = deepMerge(dstMap, srcMap)
					continue
				}
			}
		}
		// Overwrite or add the value from src to dst
		dst[key] = srcValue
	}
	return dst
}

func CombineJSONFiles() error {
	files, err := os.ReadDir(inputDir)
	if err != nil {
		return fmt.Errorf("failed to read input directory: %v", err)
	}

	combinedData := make(map[string]interface{})

	for _, file := range files {
		fmt.Printf("read JSON %s\n", file.Name())
		if filepath.Ext(file.Name()) == ".json" && file.Name() != "selector-flags.json" {
			filePath := filepath.Join(inputDir, file.Name())
			content, err := ioutil.ReadFile(filePath)
			if err != nil {
				return fmt.Errorf("failed to read file %s: %v", file.Name(), err)
			}

			var data map[string]interface{}
			if err := json.Unmarshal(content, &data); err != nil {
				return fmt.Errorf("failed to parse JSON file %s: %v", file.Name(), err)
			}

			// Perform deep merge
			combinedData = deepMerge(combinedData, data)
		}
	}

	// Ensure output directory exists
	if err := os.MkdirAll(outputDir, os.ModePerm); err != nil {
		return fmt.Errorf("failed to create output directory: %v", err)
	}

	// Write the combined data to the output file
	combinedContent, err := json.MarshalIndent(combinedData, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to serialize combined JSON: %v", err)
	}

	if err := ioutil.WriteFile(outputFile, combinedContent, 0644); err != nil {
		return fmt.Errorf("failed to write combined JSON to file: %v", err)
	}

	fmt.Printf("Combined JSON written to %s\n", outputFile)
	return nil
}

// startFileWatcher initializes a file watcher on the input directory to auto-update combined.json.
func startFileWatcher() error {
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
				// Watch for create, write, or remove events
				if event.Op&(fsnotify.Create|fsnotify.Write|fsnotify.Remove) != 0 {
					fmt.Println("Change detected in input directory. Regenerating combined.json...")
					if err := CombineJSONFiles(); err != nil {
						fmt.Printf("Error combining JSON files: %v\n", err)
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

	// Watch the input directory
	if err := watcher.Add(inputDir); err != nil {
		return fmt.Errorf("failed to watch input directory: %v", err)
	}

	fmt.Printf("File watcher started on %s\n", inputDir)
	return nil
}

func main() {
	// Create a context that listens for interrupt or terminate signals
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM, syscall.SIGINT)
	defer stop()

	// Initialize the combined JSON file on startup
	if err := CombineJSONFiles(); err != nil {
		fmt.Printf("Error during initial JSON combination: %v\n", err)
		os.Exit(1)
	}

	// Start the file watcher
	if err := startFileWatcher(); err != nil {
		fmt.Printf("Error starting file watcher: %v\n", err)
		os.Exit(1)
	}

	// Define your HTTP handlers
	http.HandleFunc("/start", startFlagdHandler)
	http.HandleFunc("/restart", restartHandler)
	http.HandleFunc("/stop", stopFlagdHandler)
	http.HandleFunc("/change", changeHandler)

	// Create the server
	server := &http.Server{Addr: ":8080"}

	// We put the signal handler into a goroutine
	go func() {
		<-ctx.Done()
		log.Printf("Received signal. Trying to shut down gracefully")
		timeout, cancel := context.WithTimeout(context.Background(), 5*time.Second)

		// Make sure all the resources the context holds are released
		// When we exit the goroutine.
		defer cancel()

		// Two options here: either srv.Shutdown() manages to shutdown the server
		// (semi-)gracefully within the timeout or we will be SIGKILLed by the OS.
		log.Printf("shutdown")
		server.Shutdown(timeout)
		log.Printf("done")
	}()

	err := startFlagd("default")
	if err != nil {
		fmt.Printf("Failed to start flagd: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Server is running on port 8080...")
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		fmt.Printf("Failed to start server: %v\n", err)
	}

	os.Remove(outputFile)
	fmt.Println("Server stopped.")
}
