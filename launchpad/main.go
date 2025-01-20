package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"strconv"
	"sync"
	"syscall"
	"time"
)

var (
	flagdCmd      *exec.Cmd
	flagdLock     sync.Mutex
	currentConfig = "default" // Default fallback configuration
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

	// Stop any currently running flagd instance
	if err := stopFlagd(); err != nil {
		return err
	}

	configPath := "./configs/" + config + ".json"

	// Start a new instance
	flagdLock.Lock()
	defer flagdLock.Unlock()
	flagdCmd = exec.Command("./flagd", "start", "--config", configPath)
	// Set up the output of flagd to be printed to the current terminal (stdout)
	flagdCmd.Stdout = os.Stdout
	flagdCmd.Stderr = os.Stderr

	if err := flagdCmd.Start(); err != nil {
		return err
	}
	log.Println("started flagd with config ", currentConfig)
	return nil
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

	fmt.Fprintf(w, "flagd will restart in %d seconds...\n", seconds)

	// Restart flagd after the specified delay
	go func(delay int) {
		time.Sleep(time.Duration(delay) * time.Second)
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
	configFile := "changing-flag.json"

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

func main() {
	// Create a context that listens for interrupt or terminate signals
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM, syscall.SIGINT)
	defer stop()

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

	fmt.Println("Server stopped.")
}
