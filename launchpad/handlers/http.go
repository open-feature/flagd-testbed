package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"openfeature.com/flagd-testbed/launchpad/pkg"
	"strconv"
)

// Response struct to standardize API responses
type Response struct {
	Status  string `json:"status"`
	Message string `json:"message"`
}

// StartFlagdHandler starts the `flagd` process
func StartFlagdHandler(w http.ResponseWriter, r *http.Request) {
	config := r.URL.Query().Get("config")

	if err := flagd.StartFlagd(config); err != nil {
		respondWithJSON(w, http.StatusInternalServerError, "error", fmt.Sprintf("Failed to start flagd: %v", err))
		return
	}
	respondWithJSON(w, http.StatusOK, "success", "flagd started successfully")
}

// RestartHandler stops and starts `flagd`
func RestartHandler(w http.ResponseWriter, r *http.Request) {
	secondsStr := r.URL.Query().Get("seconds")
	if secondsStr == "" {
		secondsStr = "5"
	}

	seconds, err := strconv.Atoi(secondsStr)
	if err != nil || seconds < 0 {
		respondWithJSON(w, http.StatusBadRequest, "error", "'seconds' must be a non-negative integer")
		return
	}

	flagd.RestartFlagd(seconds)
	respondWithJSON(w, http.StatusOK, "success", fmt.Sprintf("flagd will restart in %d seconds", seconds))
}

// StopFlagdHandler stops `flagd`
func StopFlagdHandler(w http.ResponseWriter, r *http.Request) {
	if err := flagd.StopFlagd(); err != nil {
		respondWithJSON(w, http.StatusInternalServerError, "error", fmt.Sprintf("Failed to stop flagd: %v", err))
		return
	}
	respondWithJSON(w, http.StatusOK, "success", "flagd stopped successfully")
}

// ChangeHandler triggers JSON file merging and notifies `flagd`
func ChangeHandler(w http.ResponseWriter, r *http.Request) {
	if err := flagd.CombineJSONFiles(flagd.InputDir); err != nil {
		respondWithJSON(w, http.StatusInternalServerError, "error", fmt.Sprintf("Failed to update JSON files: %v", err))
		return
	}

	respondWithJSON(w, http.StatusOK, "success", "JSON files updated successfully")
}

// Utility function to send JSON responses
func respondWithJSON(w http.ResponseWriter, statusCode int, status, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)

	response := Response{
		Status:  status,
		Message: message,
	}

	json.NewEncoder(w).Encode(response)
}
