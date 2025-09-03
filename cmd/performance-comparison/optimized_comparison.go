package main

import (
	"crypto/hmac"
	"crypto/sha1"
	"encoding/base64"
	"fmt"
	"io"
	"net/http"
	"os"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/fatih/color"
	"github.com/olekukonko/tablewriter"
)

// Test configuration
const (
	REQUESTS_PER_SCENARIO = 300 // Increased for better statistics
	CONCURRENT_WORKERS    = 25  // Higher concurrency
	TEST_BUCKET           = "test-bucket"
	TEST_OBJECT           = "test-object.txt"
)

// Test scenarios
type TestScenario struct {
	Name        string
	Description string
	URL         string
	Port        string
	APIKeys     []APIKeyConfig
}

type APIKeyConfig struct {
	AccessKey string
	SecretKey string
	Group     string
}

type RequestResult struct {
	Success       bool
	Latency       time.Duration
	StatusCode    int
	Error         string
	APIKey        string
	Group         string
	Timestamp     time.Time
	RateLimited   bool
	TestMode      string
}

type PerformanceReport struct {
	Scenario           string
	TotalRequests      int
	SuccessfulRequests int
	FailedRequests     int
	RateLimitedRequests int
	AvgLatency         time.Duration
	MinLatency         time.Duration
	MaxLatency         time.Duration
	P50Latency         time.Duration
	P95Latency         time.Duration
	P99Latency         time.Duration
	RequestsPerSecond  float64
	GroupStats         map[string]GroupStats
}

type GroupStats struct {
	Requests      int
	AvgLatency    time.Duration
	RateLimited   int
	SuccessRate   float64
}

func main() {
	color.Blue("🚀 HAProxy Optimization Performance Comparison")
	color.Blue("=" + strings.Repeat("=", 44))
	fmt.Printf("⏱️  Test Configuration:\n")
	fmt.Printf("   • Requests per scenario: %d\n", REQUESTS_PER_SCENARIO)
	fmt.Printf("   • Concurrent workers: %d\n", CONCURRENT_WORKERS)
	fmt.Printf("   • Testing optimization improvements\n")
	fmt.Println()

	// Test scenarios - comparison of optimizations
	scenarios := []TestScenario{
		{
			Name:        "Minimal_HAProxy_Baseline",
			Description: "Minimal HAProxy baseline (no auth, no rate limiting)",
			URL:         "http://localhost",
			Port:        "8083",
			APIKeys:     getTestAPIKeys(),
		},
		{
			Name:        "Original_Rate_Limiting",
			Description: "Original HAProxy rate limiting implementation",
			URL:         "http://localhost",
			Port:        "8081",
			APIKeys:     getTestAPIKeys(),
		},
		{
			Name:        "Optimized_Rate_Limiting",
			Description: "Optimized HAProxy rate limiting implementation",
			URL:         "http://localhost",
			Port:        "8084",
			APIKeys:     getTestAPIKeys(),
		},
	}

	var allResults []PerformanceReport

	for _, scenario := range scenarios {
		color.Yellow("\n📊 Running scenario: %s", scenario.Name)
		color.Cyan("   %s", scenario.Description)

		results := runPerformanceTest(scenario)
		report := generateReport(scenario.Name, results)
		allResults = append(allResults, report)

		// Brief results
		color.Green("✅ Completed: %d requests, avg latency: %v, success rate: %.1f%%",
			report.TotalRequests, report.AvgLatency,
			float64(report.SuccessfulRequests)/float64(report.TotalRequests)*100)
	}

	// Generate comprehensive comparison report
	generateOptimizationReport(allResults)
}

func getTestAPIKeys() []APIKeyConfig {
	return []APIKeyConfig{
		{"5HQZO7EDOM4XBNO642GQ", "Ct4GdhfwRbLqb+J6ckrtJw+wlWgrImTDuoRjId2Q", "premium"},
		{"VSLP8GUZ6SPYILLLGHJ0", "LmF3K8gH2pN5qR7sT9vB1cE6fJ4mP8xZ2wQ5nR7s", "standard"},
		{"FQ4IU19ZFZ3470XJ7GBF", "9sK2mN6pQ8rT5vY1wE4gH7jL0nR3sV8xZ6cF9mP2", "basic"},
		{"CC40HFGT4T11KIIRUAON", "3jK8mN1pQ4rT7vY9wE2gH5jL6nR0sV3xZ8cF1mP4", "premium"},
		{"7E6HG3VK0OFDJDXH1CE2", "7sK4mN8pQ2rT5vY3wE6gH9jL2nR5sV7xZ0cF3mP6", "standard"},
		{"A86HLL1JTI580LR6OW8U", "1sK6mN0pQ8rT3vY7wE4gH1jL8nR2sV5xZ9cF7mP0", "basic"},
	}
}

func runPerformanceTest(scenario TestScenario) []RequestResult {
	var results []RequestResult
	var resultsMutex sync.Mutex
	var wg sync.WaitGroup

	// Channel to distribute work
	requestChan := make(chan APIKeyConfig, REQUESTS_PER_SCENARIO)

	// Start workers
	for i := 0; i < CONCURRENT_WORKERS; i++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()

			for apiKey := range requestChan {
				result := performRequest(scenario, apiKey)

				resultsMutex.Lock()
				results = append(results, result)
				resultsMutex.Unlock()

				// Minimal delay
				time.Sleep(time.Microsecond * 50)
			}
		}(i)
	}

	// Distribute requests across API keys
	for i := 0; i < REQUESTS_PER_SCENARIO; i++ {
		apiKey := scenario.APIKeys[i%len(scenario.APIKeys)]
		requestChan <- apiKey
	}
	close(requestChan)

	// Wait for all workers to complete
	wg.Wait()

	return results
}

func performRequest(scenario TestScenario, apiKey APIKeyConfig) RequestResult {
	start := time.Now()

	// Create request
	objectPath := fmt.Sprintf("/%s/%s", TEST_BUCKET, TEST_OBJECT)
	fullURL := fmt.Sprintf("%s:%s%s", scenario.URL, scenario.Port, objectPath)

	req, err := http.NewRequest("GET", fullURL, nil)
	if err != nil {
		return RequestResult{
			Success:   false,
			Latency:   time.Since(start),
			Error:     err.Error(),
			APIKey:    apiKey.AccessKey,
			Group:     apiKey.Group,
			Timestamp: time.Now(),
		}
	}

	// Add authentication only for scenarios that process it
	if scenario.Port != "8083" { // Minimal HAProxy doesn't need auth
		// Add AWS Signature V2 authentication
		date := time.Now().UTC().Format(time.RFC1123Z)
		req.Header.Set("Date", date)
		req.Header.Set("Host", req.Host)

		// Create signature
		stringToSign := fmt.Sprintf("GET\n\n\n%s\n%s", date, objectPath)
		signature := sign(stringToSign, apiKey.SecretKey)
		authHeader := fmt.Sprintf("AWS %s:%s", apiKey.AccessKey, signature)
		req.Header.Set("Authorization", authHeader)
	}

	// Perform request
	client := &http.Client{
		Timeout: time.Second * 5,
	}

	resp, err := client.Do(req)
	latency := time.Since(start)

	result := RequestResult{
		Success:     err == nil,
		Latency:     latency,
		APIKey:      apiKey.AccessKey,
		Group:       apiKey.Group,
		Timestamp:   time.Now(),
		RateLimited: false,
	}

	if err != nil {
		result.Error = err.Error()
		return result
	}

	result.StatusCode = resp.StatusCode

	// Check for rate limiting
	if resp.StatusCode == 429 {
		result.RateLimited = true
		result.Success = true // Still a successful response from HAProxy perspective
	} else if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		result.Success = true
	}

	// Get test mode from response headers
	if testMode := resp.Header.Get("X-Test-Mode"); testMode != "" {
		result.TestMode = testMode
	}

	// Read and discard response body
	if resp.Body != nil {
		io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
	}

	return result
}

func sign(stringToSign, secretKey string) string {
	h := hmac.New(sha1.New, []byte(secretKey))
	h.Write([]byte(stringToSign))
	return base64.StdEncoding.EncodeToString(h.Sum(nil))
}

func generateReport(scenarioName string, results []RequestResult) PerformanceReport {
	if len(results) == 0 {
		return PerformanceReport{Scenario: scenarioName}
	}

	// Sort by latency for percentile calculations
	latencies := make([]time.Duration, len(results))
	for i, result := range results {
		latencies[i] = result.Latency
	}
	sort.Slice(latencies, func(i, j int) bool {
		return latencies[i] < latencies[j]
	})

	// Calculate statistics
	var totalLatency time.Duration
	successCount := 0
	rateLimitedCount := 0
	groupStats := make(map[string]GroupStats)

	for _, result := range results {
		totalLatency += result.Latency

		if result.Success && !result.RateLimited {
			successCount++
		}

		if result.RateLimited {
			rateLimitedCount++
		}

		// Group statistics
		group := result.Group
		if stats, exists := groupStats[group]; exists {
			stats.Requests++
			stats.AvgLatency = (stats.AvgLatency*time.Duration(stats.Requests-1) + result.Latency) / time.Duration(stats.Requests)
			if result.RateLimited {
				stats.RateLimited++
			}
			groupStats[group] = stats
		} else {
			groupStats[group] = GroupStats{
				Requests:    1,
				AvgLatency:  result.Latency,
				RateLimited: func() int {
					if result.RateLimited {
						return 1
					}
					return 0
				}(),
			}
		}
	}

	// Calculate success rates for groups
	for group, stats := range groupStats {
		stats.SuccessRate = float64(stats.Requests-stats.RateLimited) / float64(stats.Requests) * 100
		groupStats[group] = stats
	}

	avgLatency := totalLatency / time.Duration(len(results))

	// Calculate percentiles
	p50 := latencies[len(latencies)*50/100]
	p95 := latencies[len(latencies)*95/100]
	p99 := latencies[len(latencies)*99/100]

	// Calculate requests per second
	if len(results) > 0 {
		firstTime := results[0].Timestamp
		lastTime := results[len(results)-1].Timestamp
		duration := lastTime.Sub(firstTime).Seconds()
		if duration > 0 {
			return PerformanceReport{
				Scenario:            scenarioName,
				TotalRequests:       len(results),
				SuccessfulRequests:  successCount,
				FailedRequests:      len(results) - successCount - rateLimitedCount,
				RateLimitedRequests: rateLimitedCount,
				AvgLatency:          avgLatency,
				MinLatency:          latencies[0],
				MaxLatency:          latencies[len(latencies)-1],
				P50Latency:          p50,
				P95Latency:          p95,
				P99Latency:          p99,
				RequestsPerSecond:   float64(len(results)) / duration,
				GroupStats:          groupStats,
			}
		}
	}

	return PerformanceReport{
		Scenario:            scenarioName,
		TotalRequests:       len(results),
		SuccessfulRequests:  successCount,
		FailedRequests:      len(results) - successCount - rateLimitedCount,
		RateLimitedRequests: rateLimitedCount,
		AvgLatency:          avgLatency,
		MinLatency:          latencies[0],
		MaxLatency:          latencies[len(latencies)-1],
		P50Latency:          p50,
		P95Latency:          p95,
		P99Latency:          p99,
		RequestsPerSecond:   0,
		GroupStats:          groupStats,
	}
}

func generateOptimizationReport(reports []PerformanceReport) {
	color.Blue("\n📈 HAPROXY OPTIMIZATION PERFORMANCE ANALYSIS")
	color.Blue("=" + strings.Repeat("=", 44))

	if len(reports) < 3 {
		color.Red("❌ Need at least 3 scenarios for optimization comparison")
		return
	}

	baseline := reports[0]   // Minimal HAProxy
	original := reports[1]   // Original Rate Limiting
	optimized := reports[2]  // Optimized Rate Limiting

	// Performance comparison table
	fmt.Println("\n🏆 Optimization Performance Comparison:")

	table := tablewriter.NewWriter(os.Stdout)
	table.SetHeader([]string{"Implementation", "Avg Latency", "P50", "P95", "P99", "Success Rate", "RPS"})
	table.SetBorder(false)
	table.SetHeaderColor(
		tablewriter.Colors{tablewriter.Bold, tablewriter.FgHiWhiteColor},
		tablewriter.Colors{tablewriter.Bold, tablewriter.FgHiCyanColor},
		tablewriter.Colors{tablewriter.Bold, tablewriter.FgHiCyanColor},
		tablewriter.Colors{tablewriter.Bold, tablewriter.FgHiCyanColor},
		tablewriter.Colors{tablewriter.Bold, tablewriter.FgHiCyanColor},
		tablewriter.Colors{tablewriter.Bold, tablewriter.FgHiYellowColor},
		tablewriter.Colors{tablewriter.Bold, tablewriter.FgHiGreenColor},
	)

	for _, report := range reports {
		scenarioName := strings.Replace(report.Scenario, "_", " ", -1)
		table.Append([]string{
			scenarioName,
			report.AvgLatency.String(),
			report.P50Latency.String(),
			report.P95Latency.String(),
			report.P99Latency.String(),
			fmt.Sprintf("%.1f%%", float64(report.SuccessfulRequests)/float64(report.TotalRequests)*100),
			fmt.Sprintf("%.0f", report.RequestsPerSecond),
		})
	}

	table.Render()

	// Optimization improvement analysis
	fmt.Println("\n📊 Optimization Improvements:")

	improvementTable := tablewriter.NewWriter(os.Stdout)
	improvementTable.SetHeader([]string{"Metric", "Original vs Baseline", "Optimized vs Baseline", "Optimization Gain"})
	improvementTable.SetBorder(false)
	improvementTable.SetHeaderColor(
		tablewriter.Colors{tablewriter.Bold, tablewriter.FgHiWhiteColor},
		tablewriter.Colors{tablewriter.Bold, tablewriter.FgHiRedColor},
		tablewriter.Colors{tablewriter.Bold, tablewriter.FgHiBlueColor},
		tablewriter.Colors{tablewriter.Bold, tablewriter.FgHiGreenColor},
	)

	// Calculate improvements
	originalOverheadAvg := float64(original.AvgLatency-baseline.AvgLatency) / float64(baseline.AvgLatency) * 100
	optimizedOverheadAvg := float64(optimized.AvgLatency-baseline.AvgLatency) / float64(baseline.AvgLatency) * 100
	avgLatencyGain := originalOverheadAvg - optimizedOverheadAvg

	originalOverheadP95 := float64(original.P95Latency-baseline.P95Latency) / float64(baseline.P95Latency) * 100
	optimizedOverheadP95 := float64(optimized.P95Latency-baseline.P95Latency) / float64(baseline.P95Latency) * 100
	p95LatencyGain := originalOverheadP95 - optimizedOverheadP95

	originalOverheadP99 := float64(original.P99Latency-baseline.P99Latency) / float64(baseline.P99Latency) * 100
	optimizedOverheadP99 := float64(optimized.P99Latency-baseline.P99Latency) / float64(baseline.P99Latency) * 100
	p99LatencyGain := originalOverheadP99 - optimizedOverheadP99

	improvementTable.Append([]string{"Avg Latency",
		fmt.Sprintf("+%.2f%%", originalOverheadAvg),
		fmt.Sprintf("+%.2f%%", optimizedOverheadAvg),
		fmt.Sprintf("%.2f%% better", avgLatencyGain)})
	improvementTable.Append([]string{"P95 Latency",
		fmt.Sprintf("+%.2f%%", originalOverheadP95),
		fmt.Sprintf("+%.2f%%", optimizedOverheadP95),
		fmt.Sprintf("%.2f%% better", p95LatencyGain)})
	improvementTable.Append([]string{"P99 Latency",
		fmt.Sprintf("+%.2f%%", originalOverheadP99),
		fmt.Sprintf("+%.2f%%", optimizedOverheadP99),
		fmt.Sprintf("%.2f%% better", p99LatencyGain)})

	improvementTable.Render()

	// Detailed reports
	for _, report := range reports {
		color.Cyan("\n📊 Detailed Report: %s", report.Scenario)
		fmt.Printf("Total Requests: %d\n", report.TotalRequests)
		fmt.Printf("Successful: %d (%.1f%%)\n", report.SuccessfulRequests,
			float64(report.SuccessfulRequests)/float64(report.TotalRequests)*100)
		fmt.Printf("Rate Limited: %d\n", report.RateLimitedRequests)

		fmt.Printf("\nLatency Statistics:\n")
		fmt.Printf("  Average: %v\n", report.AvgLatency)
		fmt.Printf("  Minimum: %v\n", report.MinLatency)
		fmt.Printf("  Maximum: %v\n", report.MaxLatency)
		fmt.Printf("  P50: %v\n", report.P50Latency)
		fmt.Printf("  P95: %v\n", report.P95Latency)
		fmt.Printf("  P99: %v\n", report.P99Latency)
		fmt.Printf("  Requests/sec: %.2f\n", report.RequestsPerSecond)
	}

	// Key optimization insights
	color.Blue("\n💡 Optimization Impact Analysis:")
	fmt.Printf("• Baseline HAProxy latency: %v\n", baseline.AvgLatency)
	fmt.Printf("• Original rate limiting overhead: +%.2f%%\n", originalOverheadAvg)
	fmt.Printf("• Optimized rate limiting overhead: +%.2f%%\n", optimizedOverheadAvg)
	fmt.Printf("• Performance improvement: %.2f%% reduction in overhead\n", avgLatencyGain)

	if avgLatencyGain > 0 {
		color.Green("✅ Optimizations successful: %.2f%% latency improvement achieved", avgLatencyGain)
	} else {
		color.Yellow("⚠️ Optimizations show %.2f%% change (may need further tuning)", avgLatencyGain)
	}

	color.Blue("\n🔧 Optimization Techniques Applied:")
	fmt.Println("• Pre-compiled Lua regex patterns")
	fmt.Println("• Early exit optimizations in Lua functions")
	fmt.Println("• Conditional header processing")
	fmt.Println("• Optimized stick table configurations")
	fmt.Println("• Performance-tuned HAProxy settings")
	fmt.Println("• Reduced unnecessary map lookups")

	color.Blue("\n🎯 Optimization performance analysis completed!")
}