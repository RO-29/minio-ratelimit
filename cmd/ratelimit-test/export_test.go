package main

import (
	"encoding/json"
	"os"
	"testing"
	"time"
)

func TestExportToJSON(t *testing.T) {
	// Create a temporary output file
	tempFile, err := os.CreateTemp("", "test_export_*.json")
	if err != nil {
		t.Fatalf("Failed to create temp file: %v", err)
	}
	defer os.Remove(tempFile.Name())
	tempFile.Close()

	// Create sample test data
	summary := TestSummary{
		TotalTests:    3,
		TotalRequests: 100,
		TotalSuccess:  75,
		TotalLimited:  20,
		TotalErrors:   5,
		Duration:      5 * time.Second,
		ByGroup: map[string]TestResult{
			"basic": {
				Group:        "basic",
				RequestsSent: 30,
				Success:      25,
			},
		},
		HeaderAnalysis: HeaderAnalysis{
			UniqueAuthMethods: []string{"test-method"},
			RateLimitHeaders:  map[string]int64{"X-Ratelimit-Limit": 100},
		},
	}

	results := []TestResult{
		{
			APIKey:       "test-key",
			Group:        "basic",
			Method:       "MinIO-Go",
			RequestsSent: 30,
			Success:      25,
		},
	}

	// Export the data
	exportToJSON(summary, results, tempFile.Name())

	// Verify the file exists and contains valid JSON
	fileData, err := os.ReadFile(tempFile.Name())
	if err != nil {
		t.Fatalf("Failed to read exported file: %v", err)
	}

	var exportedData map[string]interface{}
	if err := json.Unmarshal(fileData, &exportedData); err != nil {
		t.Fatalf("Exported file doesn't contain valid JSON: %v", err)
	}

	// Verify basic structure
	if _, ok := exportedData["summary"]; !ok {
		t.Error("Exported JSON missing 'summary' field")
	}

	if _, ok := exportedData["detailed_results"]; !ok {
		t.Error("Exported JSON missing 'detailed_results' field")
	}

	if _, ok := exportedData["version"]; !ok {
		t.Error("Exported JSON missing 'version' field")
	}
}

func TestGetTotalHeaderCapturesWithNil(t *testing.T) {
	results := []TestResult{
		{HeaderCaptures: make([]ResponseHeaders, 5)},
		{HeaderCaptures: make([]ResponseHeaders, 3)},
		{HeaderCaptures: nil},
	}

	total := getTotalHeaderCaptures(results)
	expected := 8 // 5 + 3 + 0

	if total != expected {
		t.Errorf("Expected %d total header captures, got %d", expected, total)
	}
}
