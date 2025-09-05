// compare_results.go
// A simple tool to compare two MinIO rate limit test result files

package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"sort"
	"strings"
	"text/tabwriter"
)

// Define simplified result structures
type Summary struct {
	TotalRequests      int                  `json:"TotalRequests"`
	TotalSuccess       int                  `json:"TotalSuccess"`
	TotalLimited       int                  `json:"TotalLimited"`
	TotalErrors        int                  `json:"TotalErrors"`
	TotalTests         int                  `json:"TotalTests"`
	SuccessRate        float64              `json:"SuccessRate"`
	LimitRate          float64              `json:"LimitRate"`
	AverageRequestsRPS float64              `json:"AverageRequestsRPS"`
	MaxRPS             float64              `json:"MaxRPS"`
	TestDuration       float64              `json:"TestDuration"`
	TierBreakdown      map[string]TierStats `json:"TierBreakdown"`
}

type TierStats struct {
	Accounts      int                    `json:"Accounts"`
	Requests      int                    `json:"Requests"`
	Success       int                    `json:"Success"`
	Limited       int                    `json:"Limited"`
	Errors        int                    `json:"Errors"`
	SuccessRate   float64                `json:"SuccessRate"`
	LimitRate     float64                `json:"LimitRate"`
	AverageRPS    float64                `json:"AverageRPS"`
	MaxRPS        float64                `json:"MaxRPS"`
	HeaderDetails map[string]interface{} `json:"HeaderDetails,omitempty"`
}

type TestResults struct {
	Summary Summary `json:"summary"`
}

func main() {
	// Parse command-line flags
	file1 := flag.String("file1", "", "First result file to compare")
	file2 := flag.String("file2", "", "Second result file to compare")
	flag.Parse()

	if *file1 == "" || *file2 == "" {
		fmt.Println("Error: Both file1 and file2 parameters are required")
		flag.Usage()
		os.Exit(1)
	}

	// Load result files
	result1, err := loadResults(*file1)
	if err != nil {
		fmt.Printf("Error loading %s: %v\n", *file1, err)
		os.Exit(1)
	}

	result2, err := loadResults(*file2)
	if err != nil {
		fmt.Printf("Error loading %s: %v\n", *file2, err)
		os.Exit(1)
	}

	// Compare results
	compareResults(*file1, result1, *file2, result2)
}

func loadResults(filename string) (*TestResults, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}

	var results TestResults
	if err := json.Unmarshal(data, &results); err != nil {
		return nil, err
	}

	return &results, nil
}

func compareResults(name1 string, result1 *TestResults, name2 string, result2 *TestResults) {
	// Create a tab writer for formatted output
	w := tabwriter.NewWriter(os.Stdout, 0, 0, 3, ' ', tabwriter.AlignRight)

	// Print comparison header
	shortName1 := getShortName(name1)
	shortName2 := getShortName(name2)
	fmt.Println("📊 RATE LIMIT TEST COMPARISON")
	fmt.Println("============================")
	fmt.Printf("Comparing: \n - %s\n - %s\n\n", name1, name2)

	// Print summary comparison
	fmt.Fprintf(w, "METRIC\t%s\t%s\tDIFFERENCE\t%%CHANGE\n", shortName1, shortName2)
	fmt.Fprintf(w, "------\t------\t------\t----------\t-------\n")

	// Key metrics
	compareMetric(w, "Total Requests", result1.Summary.TotalRequests, result2.Summary.TotalRequests)
	compareMetric(w, "Success Rate", result1.Summary.SuccessRate, result2.Summary.SuccessRate)
	compareMetric(w, "Rate Limited", result1.Summary.TotalLimited, result2.Summary.TotalLimited)
	compareMetric(w, "Limit Rate", result1.Summary.LimitRate, result2.Summary.LimitRate)
	compareMetric(w, "Avg RPS", result1.Summary.AverageRequestsRPS, result2.Summary.AverageRequestsRPS)
	compareMetric(w, "Max RPS", result1.Summary.MaxRPS, result2.Summary.MaxRPS)
	compareMetric(w, "Duration (s)", result1.Summary.TestDuration, result2.Summary.TestDuration)

	w.Flush()

	// Print tier breakdowns if available
	fmt.Println("\n📊 TIER BREAKDOWN COMPARISON")
	fmt.Println("===========================")

	// Get all tiers from both results
	tiers := make(map[string]bool)
	for tier := range result1.Summary.TierBreakdown {
		tiers[tier] = true
	}
	for tier := range result2.Summary.TierBreakdown {
		tiers[tier] = true
	}

	// Sort tiers
	tierNames := make([]string, 0, len(tiers))
	for tier := range tiers {
		tierNames = append(tierNames, tier)
	}
	sort.Strings(tierNames)

	// Compare each tier
	for _, tier := range tierNames {
		fmt.Printf("\n🔶 %s TIER\n", strings.ToUpper(tier))
		w = tabwriter.NewWriter(os.Stdout, 0, 0, 3, ' ', tabwriter.AlignRight)
		fmt.Fprintf(w, "METRIC\t%s\t%s\tDIFFERENCE\t%%CHANGE\n", shortName1, shortName2)
		fmt.Fprintf(w, "------\t------\t------\t----------\t-------\n")

		tier1 := result1.Summary.TierBreakdown[tier]
		tier2 := result2.Summary.TierBreakdown[tier]

		if tier1.Accounts == 0 {
			fmt.Fprintf(w, "Note: No %s tier accounts in %s\n", tier, shortName1)
		} else if tier2.Accounts == 0 {
			fmt.Fprintf(w, "Note: No %s tier accounts in %s\n", tier, shortName2)
		} else {
			compareMetric(w, "Accounts", tier1.Accounts, tier2.Accounts)
			compareMetric(w, "Requests", tier1.Requests, tier2.Requests)
			compareMetric(w, "Success Rate", tier1.SuccessRate, tier2.SuccessRate)
			compareMetric(w, "Limit Rate", tier1.LimitRate, tier2.LimitRate)
			compareMetric(w, "Avg RPS", tier1.AverageRPS, tier2.AverageRPS)
			compareMetric(w, "Max RPS", tier1.MaxRPS, tier2.MaxRPS)
		}

		w.Flush()
	}

	fmt.Println("\n🏁 Comparison complete!")
}

func compareMetric(w *tabwriter.Writer, name string, val1, val2 interface{}) {
	var diff, percent string

	// Handle different types
	switch v1 := val1.(type) {
	case int:
		v2, ok := val2.(int)
		if !ok {
			fmt.Fprintf(w, "%s\t%d\t%v\tIncomparable\t-\n", name, v1, val2)
			return
		}
		delta := v2 - v1
		var pct float64
		if v1 != 0 {
			pct = float64(delta) / float64(v1) * 100
		}
		diff = fmt.Sprintf("%d", delta)
		if delta > 0 {
			diff = "+" + diff
		}
		percent = fmt.Sprintf("%.1f%%", pct)
		fmt.Fprintf(w, "%s\t%d\t%d\t%s\t%s\n", name, v1, v2, diff, percent)

	case float64:
		v2, ok := val2.(float64)
		if !ok {
			fmt.Fprintf(w, "%s\t%.2f\t%v\tIncomparable\t-\n", name, v1, val2)
			return
		}
		delta := v2 - v1
		var pct float64
		if v1 != 0 {
			pct = delta / v1 * 100
		}
		diff = fmt.Sprintf("%.2f", delta)
		if delta > 0 {
			diff = "+" + diff
		}
		percent = fmt.Sprintf("%.1f%%", pct)
		fmt.Fprintf(w, "%s\t%.2f\t%.2f\t%s\t%s\n", name, v1, v2, diff, percent)

	default:
		fmt.Fprintf(w, "%s\t%v\t%v\t-\t-\n", name, val1, val2)
	}
}

func getShortName(path string) string {
	parts := strings.Split(path, "/")
	return parts[len(parts)-1]
}
