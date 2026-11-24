package flagd

import (
	"encoding/json"
	"os"
	"reflect"
	"testing"
	"time"
)

// Test JSON merging
func TestCombineJSONFiles(t *testing.T) {
	// Setup: Create temp input directory
	testInputDir := "./test_rawflags"
	os.MkdirAll(testInputDir, os.ModePerm)
	defer os.RemoveAll(testInputDir) // Cleanup after test

	// Create sample JSON files
	json1 := `{"flags": {"feature1": {"state": "on"}}}`
	json2 := `{"flags": {"feature2": {"state": "off"}}}`
	os.WriteFile(testInputDir+"/file1.json", []byte(json1), 0644)
	os.WriteFile(testInputDir+"/file2.json", []byte(json2), 0644)

	// Run function
	err := CombineJSONFiles(testInputDir)
	if err != nil {
		t.Fatalf("CombineJSONFiles failed: %v", err)
	}

	// Verify output
	expected := `{"flags":{"feature1":{"state":"on"},"feature2":{"state":"off"}}}`
	data, _ := os.ReadFile(OutputFile)

	var v1, v2 interface{}

	json.Unmarshal([]byte(expected), &v1)
	json.Unmarshal(data, &v2)
	if !reflect.DeepEqual(v1, v2) {
		t.Errorf("Expected %s, got %s", expected, string(data))
	}
}

// Test that selector files are mirrored as-is and identical content isn't rewritten
func TestCombineJSONFilesMirrorsSelectorFiles(t *testing.T) {
	testInputDir := "./test_rawflags_selector"
	os.MkdirAll(testInputDir, os.ModePerm)
	defer os.RemoveAll(testInputDir)
	defer os.RemoveAll(outputDir)

	plain := `{"flags": {"feature1": {"state": "on"}}}`
	selector := `{"flags": {"feature2": {"state": "off"}}, "metadata": {"version": "1"}}`
	os.WriteFile(testInputDir+"/file1.json", []byte(plain), 0644)
	os.WriteFile(testInputDir+"/selector-file2.json", []byte(selector), 0644)

	if err := CombineJSONFiles(testInputDir); err != nil {
		t.Fatalf("CombineJSONFiles failed: %v", err)
	}

	mirrored, err := os.ReadFile(outputDir + "/selector-file2.json")
	if err != nil {
		t.Fatalf("selector file was not mirrored: %v", err)
	}
	if string(mirrored) != selector {
		t.Errorf("Expected mirrored content %s, got %s", selector, string(mirrored))
	}

	var combined map[string]interface{}
	data, _ := os.ReadFile(OutputFile)
	json.Unmarshal(data, &combined)
	if _, ok := combined["metadata"]; ok {
		t.Errorf("selector file was merged into %s: %s", OutputFile, string(data))
	}

	before := map[string]os.FileInfo{}
	for _, f := range []string{OutputFile, outputDir + "/selector-file2.json"} {
		before[f], _ = os.Stat(f)
	}
	time.Sleep(10 * time.Millisecond)
	if err := CombineJSONFiles(testInputDir); err != nil {
		t.Fatalf("CombineJSONFiles failed: %v", err)
	}
	for f, info := range before {
		after, _ := os.Stat(f)
		if !after.ModTime().Equal(info.ModTime()) {
			t.Errorf("%s was rewritten with identical content", f)
		}
	}
}
