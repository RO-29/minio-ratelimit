package main

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha1"
	"encoding/base64"
	"fmt"
	"io"
	"net/http"
	"os"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/fatih/color"
	"github.com/olekukonko/tablewriter"
)

// Test configuration
const (
	REQUESTS_PER_SCENARIO = 100 // 100 requests per scenario for better statistics
	CONCURRENT_WORKERS    = 15  // 15 concurrent workers
	TEST_BUCKET          = "test-bucket"
	TEST_CONTENT         = "This is test content for performance comparison"
)

// Test scenarios
type TestScenario struct {
	Name        string
	Description string
	URL         string
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
	RequestType   string
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
	color.Blue("🚀 Realistic HAProxy Rate Limiting Performance Test")
	color.Blue("=" + strings.Repeat("=", 52))
	fmt.Printf("⏱️  Test Configuration:\n")
	fmt.Printf("   • Requests per scenario: %d\n", REQUESTS_PER_SCENARIO)
	fmt.Printf("   • Concurrent workers: %d\n", CONCURRENT_WORKERS)
	fmt.Printf("   • Request types: PUT (upload) and GET (download)\n")
	fmt.Println()

	// Test scenarios
	scenarios := []TestScenario{
		{
			Name:        "HAProxy_With_Rate_Limiting",
			Description: "HAProxy with full dynamic rate limiting enabled",
			URL:         "http://localhost:80",
			APIKeys:     getTestAPIKeys(),
		},
		{
			Name:        "HAProxy_Without_Rate_Limiting",
			Description: "HAProxy with rate limiting disabled (auth parsing only)",
			URL:         "http://localhost:8080",
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
	generateComparisonReport(allResults)
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
	workChan := make(chan WorkItem, REQUESTS_PER_SCENARIO)

	// Start workers
	for i := 0; i < CONCURRENT_WORKERS; i++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()

			for work := range workChan {
				result := performRequest(scenario, work)

				resultsMutex.Lock()
				results = append(results, result)
				resultsMutex.Unlock()

				// Small delay to avoid overwhelming
				time.Sleep(time.Millisecond * 20)
			}
		}(i)
	}

	// Generate work items - mix of PUT and GET requests
	for i := 0; i < REQUESTS_PER_SCENARIO; i++ {
		apiKey := scenario.APIKeys[i%len(scenario.APIKeys)]
		objectKey := fmt.Sprintf("perf-test-%d-%d.txt", time.Now().Unix(), i)

		// Alternate between PUT and GET requests
		requestType := "PUT"
		if i%2 == 1 {
			requestType = "GET"
		}

		workChan <- WorkItem{
			APIKey:      apiKey,
			RequestType: requestType,
			ObjectKey:   objectKey,
		}
	}
	close(workChan)

	// Wait for all workers to complete
	wg.Wait()

	return results
}

type WorkItem struct {
	APIKey      APIKeyConfig
	RequestType string
	ObjectKey   string
}

func performRequest(scenario TestScenario, work WorkItem) RequestResult {
	start := time.Now()

	// Create request
	objectPath := fmt.Sprintf("/%s/%s", TEST_BUCKET, work.ObjectKey)
	fullURL := scenario.URL + objectPath

	var req *http.Request
	var err error

	if work.RequestType == "PUT" {
		// PUT request with content
		body := bytes.NewBufferString(TEST_CONTENT)
		req, err = http.NewRequest("PUT", fullURL, body)
		if req != nil {
			req.Header.Set("Content-Type", "text/plain")
			req.Header.Set("Content-Length", strconv.Itoa(len(TEST_CONTENT)))
		}
	} else {
		// GET request
		req, err = http.NewRequest("GET", fullURL, nil)
	}

	if err != nil {
		return RequestResult{
			Success:     false,
			Latency:     time.Since(start),
			Error:       err.Error(),
			APIKey:      work.APIKey.AccessKey,
			Group:       work.APIKey.Group,
			Timestamp:   time.Now(),
			RequestType: work.RequestType,
		}
	}

	// Add AWS Signature V2 authentication
	date := time.Now().UTC().Format(time.RFC1123Z)
	req.Header.Set("Date", date)
	req.Header.Set("Host", req.Host)

	// Create signature
	contentMD5 := ""
	contentType := req.Header.Get("Content-Type")
	stringToSign := fmt.Sprintf("%s\n%s\n%s\n%s\n%s", work.RequestType, contentMD5, contentType, date, objectPath)
	signature := sign(stringToSign, work.APIKey.SecretKey)
	authHeader := fmt.Sprintf("AWS %s:%s", work.APIKey.AccessKey, signature)
	req.Header.Set("Authorization", authHeader)

	// Perform request
	client := &http.Client{
		Timeout: time.Second * 10,
	}

	resp, err := client.Do(req)
	latency := time.Since(start)

	result := RequestResult{
		Success:     err == nil,
		Latency:     latency,
		APIKey:      work.APIKey.AccessKey,
		Group:       work.APIKey.Group,
		Timestamp:   time.Now(),
		RateLimited: false,
		RequestType: work.RequestType,
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

func generateComparisonReport(reports []PerformanceReport) {
	color.Blue("\n📈 COMPREHENSIVE PERFORMANCE COMPARISON REPORT")
	color.Blue("=" + strings.Repeat("=", 50))

	if len(reports) < 2 {
		color.Red("❌ Need at least 2 scenarios for comparison")
		return
	}

	// Overall comparison table
	fmt.Println("\n🏆 Overall Performance Comparison:")

	table := tablewriter.NewWriter(os.Stdout)
	table.SetHeader([]string{"Metric", "With Rate Limiting", "Without Rate Limiting", "Overhead"})
	table.SetBorder(false)
	table.SetHeaderColor(
		tablewriter.Colors{tablewriter.Bold, tablewriter.FgHiWhiteColor},
		tablewriter.Colors{tablewriter.Bold, tablewriter.FgHiGreenColor},
		tablewriter.Colors{tablewriter.Bold, tablewriter.FgHiBlueColor},
		tablewriter.Colors{tablewriter.Bold, tablewriter.FgHiYellowColor},
	)

	withRL := reports[0]  // With Rate Limiting
	withoutRL := reports[1] // Without Rate Limiting

	// Calculate overhead percentages
	avgLatencyOverhead := float64(withRL.AvgLatency-withoutRL.AvgLatency) / float64(withoutRL.AvgLatency) * 100
	p95LatencyOverhead := float64(withRL.P95Latency-withoutRL.P95Latency) / float64(withoutRL.P95Latency) * 100
	p99LatencyOverhead := float64(withRL.P99Latency-withoutRL.P99Latency) / float64(withoutRL.P99Latency) * 100

	table.Append([]string{"Avg Latency", withRL.AvgLatency.String(), withoutRL.AvgLatency.String(),
		fmt.Sprintf("+%.2f%%", avgLatencyOverhead)})
	table.Append([]string{"P95 Latency", withRL.P95Latency.String(), withoutRL.P95Latency.String(),
		fmt.Sprintf("+%.2f%%", p95LatencyOverhead)})
	table.Append([]string{"P99 Latency", withRL.P99Latency.String(), withoutRL.P99Latency.String(),
		fmt.Sprintf("+%.2f%%", p99LatencyOverhead)})
	table.Append([]string{"Min Latency", withRL.MinLatency.String(), withoutRL.MinLatency.String(), "-"})
	table.Append([]string{"Max Latency", withRL.MaxLatency.String(), withoutRL.MaxLatency.String(), "-"})
	table.Append([]string{"Success Rate",
		fmt.Sprintf("%.1f%%", float64(withRL.SuccessfulRequests)/float64(withRL.TotalRequests)*100),
		fmt.Sprintf("%.1f%%", float64(withoutRL.SuccessfulRequests)/float64(withoutRL.TotalRequests)*100),
		"-"})
	table.Append([]string{"Rate Limited", strconv.Itoa(withRL.RateLimitedRequests), strconv.Itoa(withoutRL.RateLimitedRequests), "-"})

	table.Render()

	// Detailed scenario reports
	for _, report := range reports {
		color.Cyan("\n📊 Detailed Report: %s", report.Scenario)
		fmt.Printf("Total Requests: %d\n", report.TotalRequests)
		fmt.Printf("Successful: %d (%.1f%%)\n", report.SuccessfulRequests,
			float64(report.SuccessfulRequests)/float64(report.TotalRequests)*100)
		fmt.Printf("Rate Limited: %d\n", report.RateLimitedRequests)
		fmt.Printf("Failed: %d\n", report.FailedRequests)

		fmt.Printf("\nLatency Statistics:\n")
		fmt.Printf("  Average: %v\n", report.AvgLatency)
		fmt.Printf("  Minimum: %v\n", report.MinLatency)
		fmt.Printf("  Maximum: %v\n", report.MaxLatency)
		fmt.Printf("  P50 (Median): %v\n", report.P50Latency)
		fmt.Printf("  P95: %v\n", report.P95Latency)
		fmt.Printf("  P99: %v\n", report.P99Latency)
		fmt.Printf("  Requests/sec: %.2f\n", report.RequestsPerSecond)

		// Group-specific statistics
		if len(report.GroupStats) > 0 {
			fmt.Printf("\nPer-Group Statistics:\n")
			groupTable := tablewriter.NewWriter(os.Stdout)
			groupTable.SetHeader([]string{"Group", "Requests", "Avg Latency", "Rate Limited", "Success Rate"})
			groupTable.SetBorder(false)

			for group, stats := range report.GroupStats {
				groupTable.Append([]string{
					group,
					strconv.Itoa(stats.Requests),
					stats.AvgLatency.String(),
					strconv.Itoa(stats.RateLimited),
					fmt.Sprintf("%.1f%%", stats.SuccessRate),
				})
			}
			groupTable.Render()
		}
	}

	// Performance insights
	color.Blue("\n💡 Performance Insights:")
	fmt.Printf("• Rate limiting adds %.2f%% average latency overhead\n", avgLatencyOverhead)
	fmt.Printf("• P95 latency overhead: %.2f%%\n", p95LatencyOverhead)
	fmt.Printf("• P99 latency overhead: %.2f%%\n", p99LatencyOverhead)

	if avgLatencyOverhead < 10 {
		color.Green("✅ Excellent: Rate limiting overhead is minimal (<10%%)")
	} else if avgLatencyOverhead < 25 {
		color.Yellow("⚠️  Acceptable: Rate limiting overhead is moderate (10-25%%)")
	} else if avgLatencyOverhead < 50 {
		color.Red("⚠️ Moderate: Rate limiting overhead is noticeable (25-50%%)")
	} else {
		color.Red("❌ High: Rate limiting overhead is significant (>50%%)")
	}

	fmt.Printf("\n• Total requests processed: %d\n", withRL.TotalRequests+withoutRL.TotalRequests)
	if withRL.RateLimitedRequests > 0 {
		fmt.Printf("• Rate limiting effectiveness: %d requests were limited\n", withRL.RateLimitedRequests)
	} else {
		fmt.Printf("• Rate limiting effectiveness: No requests hit rate limits during test\n")
	}

	color.Blue("\n🎯 Realistic performance test completed successfully!")
}