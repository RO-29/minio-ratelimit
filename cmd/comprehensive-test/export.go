package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"time"
)

// exportToJSON exports test results and summary to a JSON file for analysis
func exportToJSON(summary TestSummary, results []TestResult, filename string) {
	exportData := struct {
		Summary    TestSummary  `json:"summary"`
		Results    []TestResult `json:"detailed_results"`
		ExportTime time.Time    `json:"export_time"`
		Version    string       `json:"version"`
	}{
		Summary:    summary,
		Results:    results,
		ExportTime: time.Now(),
		Version:    "1.0.0",
	}

	jsonData, err := json.MarshalIndent(exportData, "", "  ")
	if err != nil {
		fmt.Printf("⚠️  Error exporting to JSON: %v\n", err)
		return
	}

	err = ioutil.WriteFile(filename, jsonData, 0644)
	if err != nil {
		fmt.Printf("⚠️  Error writing JSON file: %v\n", err)
		return
	}

	fmt.Printf("📁 Results exported to %s (%.1f KB)\n", filename, float64(len(jsonData))/1024)
	fmt.Printf("📊 JSON contains: Summary + %d detailed test results + %d total header captures\n",
		len(results), getTotalHeaderCaptures(results))
}

// getTotalHeaderCaptures counts the total number of header captures across all results
func getTotalHeaderCaptures(results []TestResult) int {
	total := 0
	for _, result := range results {
		total += len(result.HeaderCaptures)
	}
	return total
}
