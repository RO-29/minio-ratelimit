package main

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"crypto/tls"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/fatih/color"
	"github.com/olekukonko/tablewriter"
)

// APIKey represents a generated API key with metadata
type APIKey struct {
	AccessKey string    `json:"access_key"`
	SecretKey string    `json:"secret_key"`
	Group     string    `json:"group"`
	Created   time.Time `json:"created"`
}

// TestScenario defines a testing scenario
type TestScenario struct {
	Name           string
	APIKeys        []APIKey
	RequestsPerSec int
	DurationSec    int
	Method         string
	Protocol       string // http or https
	Port           string
}

// TestResult stores results from a test scenario
type TestResult struct {
	Scenario            string
	APIKey              string
	Group               string
	TotalRequests       int
	SuccessfulRequests  int
	RateLimitedRequests int
	ErrorRequests       int
	AverageLatency      time.Duration
	MaxLatency          time.Duration
	MinLatency          time.Duration
	RequestsPerSecond   float64
	ActualDuration      time.Duration
}

// StatsCollector aggregates test statistics
type StatsCollector struct {
	mutex   sync.Mutex
	Results []TestResult
}

func (sc *StatsCollector) AddResult(result TestResult) {
	sc.mutex.Lock()
	defer sc.mutex.Unlock()
	sc.Results = append(sc.Results, result)
}

func main() {
	color.Cyan("🚀 HAProxy MinIO Rate Limiting Test Suite")
	color.Cyan("==========================================")

	fmt.Println()

	// Step 1: Generate real API keys
	color.Yellow("📋 Step 1: Generating AWS-compatible API keys...")
	apiKeys := generateAPIKeys()

	// Step 2: Configure HAProxy with generated keys
	color.Yellow("⚙️  Step 2: Configuring HAProxy with generated API keys...")
	if err := configureHAProxy(apiKeys); err != nil {
		color.Red("❌ Failed to configure HAProxy: %v", err)
		return
	}

	// Step 3: Start services
	color.Yellow("🐳 Step 3: Starting Docker services...")
	if err := startServices(); err != nil {
		color.Red("❌ Failed to start services: %v", err)
		return
	}

	// Wait for services to be ready
	color.Yellow("⏳ Waiting for services to be ready...")
	time.Sleep(10 * time.Second)

	// Step 4: Run test scenarios
	color.Yellow("🧪 Step 4: Running comprehensive test scenarios...")
	scenarios := createTestScenarios(apiKeys)

	statsCollector := &StatsCollector{}

	// Run all scenarios in parallel
	var wg sync.WaitGroup
	for _, scenario := range scenarios {
		wg.Add(1)
		go func(s TestScenario) {
			defer wg.Done()
			runTestScenario(s, statsCollector)
		}(scenario)
	}

	wg.Wait()

	// Step 5: Generate comprehensive report
	color.Yellow("📊 Step 5: Generating comprehensive test report...")
	generateReport(statsCollector.Results)

	color.Green("✅ Test suite completed successfully!")
}

// generateAPIKeys creates AWS-compatible API keys for different groups
func generateAPIKeys() []APIKey {
	var keys []APIKey

	groups := map[string]int{
		"premium":  5,
		"standard": 8,
		"basic":    12,
	}

	for group, count := range groups {
		color.Cyan("  Generating %d %s API keys...", count, group)

		for i := 0; i < count; i++ {
			accessKey := generateAWSAccessKey()
			secretKey := generateAWSSecretKey()

			key := APIKey{
				AccessKey: accessKey,
				SecretKey: secretKey,
				Group:     group,
				Created:   time.Now(),
			}

			keys = append(keys, key)
		}
	}

	color.Green("  ✅ Generated %d total API keys", len(keys))
	return keys
}

// generateAWSAccessKey creates a realistic AWS access key
func generateAWSAccessKey() string {
	// AWS access keys are 20 characters, starting with AKIA for regular users
	prefix := "AKIA"
	remaining := 16

	bytes := make([]byte, remaining/2)
	rand.Read(bytes)

	return prefix + strings.ToUpper(hex.EncodeToString(bytes))
}

// generateAWSSecretKey creates a realistic AWS secret key
func generateAWSSecretKey() string {
	// AWS secret keys are 40 characters, base64-like
	chars := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	result := make([]byte, 40)

	for i := 0; i < 40; i++ {
		randomBytes := make([]byte, 1)
		rand.Read(randomBytes)
		result[i] = chars[int(randomBytes[0])%len(chars)]
	}

	return string(result)
}

// configureHAProxy updates the API key configuration
func configureHAProxy(keys []APIKey) error {
	// Create API key mapping
	apiKeyConfig := make(map[string]string)
	for _, key := range keys {
		apiKeyConfig[key.AccessKey] = key.Group
	}

	// Convert to JSON
	jsonData, err := json.MarshalIndent(apiKeyConfig, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal API keys: %v", err)
	}

	// Write to configuration file
	configPath := "config/api_keys.json"
	if err := os.WriteFile(configPath, jsonData, 0644); err != nil {
		return fmt.Errorf("failed to write config file: %v", err)
	}

	color.Green("  ✅ Updated %s with %d API keys", configPath, len(keys))
	return nil
}

// startServices starts Docker services
func startServices() error {
	cmd := exec.Command("docker-compose", "down")
	cmd.Run() // Ignore errors for cleanup

	cmd = exec.Command("docker-compose", "up", "-d")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to start docker-compose: %v", err)
	}

	color.Green("  ✅ Docker services started")
	return nil
}

// createTestScenarios defines various testing scenarios
func createTestScenarios(keys []APIKey) []TestScenario {
	scenarios := []TestScenario{
		// HTTP Tests
		{
			Name:           "HTTP_Premium_Burst_Test",
			APIKeys:        filterKeysByGroup(keys, "premium"),
			RequestsPerSec: 60, // Above 50/sec burst limit
			DurationSec:    30,
			Method:         "GET",
			Protocol:       "http",
			Port:           "80",
		},
		{
			Name:           "HTTP_Standard_Sustained_Test",
			APIKeys:        filterKeysByGroup(keys, "standard"),
			RequestsPerSec: 10, // Within limits
			DurationSec:    60,
			Method:         "GET",
			Protocol:       "http",
			Port:           "80",
		},
		{
			Name:           "HTTP_Basic_Overload_Test",
			APIKeys:        filterKeysByGroup(keys, "basic"),
			RequestsPerSec: 15, // Above 10/sec burst limit
			DurationSec:    45,
			Method:         "PUT",
			Protocol:       "http",
			Port:           "80",
		},
		// HTTPS Tests
		{
			Name:           "HTTPS_Premium_Mixed_Methods",
			APIKeys:        filterKeysByGroup(keys, "premium")[:2], // Just 2 keys
			RequestsPerSec: 25,
			DurationSec:    30,
			Method:         "GET",
			Protocol:       "https",
			Port:           "443",
		},
		{
			Name:           "HTTPS_Cross_Group_Comparison",
			APIKeys:        []APIKey{keys[0], keys[5], keys[10]}, // One from each group
			RequestsPerSec: 20,
			DurationSec:    60,
			Method:         "PUT",
			Protocol:       "https",
			Port:           "443",
		},
		// Active-Active Test
		{
			Name:           "Active_Active_Load_Distribution",
			APIKeys:        filterKeysByGroup(keys, "standard")[:3],
			RequestsPerSec: 15,
			DurationSec:    45,
			Method:         "GET",
			Protocol:       "http",
			Port:           "81", // Second HAProxy instance
		},
	}

	return scenarios
}

// filterKeysByGroup returns keys of a specific group
func filterKeysByGroup(keys []APIKey, group string) []APIKey {
	var filtered []APIKey
	for _, key := range keys {
		if key.Group == group {
			filtered = append(filtered, key)
		}
	}
	return filtered
}

// runTestScenario executes a single test scenario
func runTestScenario(scenario TestScenario, collector *StatsCollector) {
	color.Magenta("  🧪 Running scenario: %s", scenario.Name)

	var wg sync.WaitGroup

	for _, apiKey := range scenario.APIKeys {
		wg.Add(1)
		go func(key APIKey) {
			defer wg.Done()
			result := testAPIKey(scenario, key)
			collector.AddResult(result)
		}(apiKey)
	}

	wg.Wait()
	color.Green("  ✅ Completed scenario: %s", scenario.Name)
}

// testAPIKey tests a single API key with the given scenario
func testAPIKey(scenario TestScenario, key APIKey) TestResult {
	result := TestResult{
		Scenario: scenario.Name,
		APIKey:   key.AccessKey,
		Group:    key.Group,
	}

	baseURL := fmt.Sprintf("%s://localhost:%s", scenario.Protocol, scenario.Port)
	client := &http.Client{
		Timeout: 10 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
		},
	}

	startTime := time.Now()
	endTime := startTime.Add(time.Duration(scenario.DurationSec) * time.Second)

	var latencies []time.Duration
	ticker := time.NewTicker(time.Second / time.Duration(scenario.RequestsPerSec))
	defer ticker.Stop()

	for time.Now().Before(endTime) {
		select {
		case <-ticker.C:
			reqStart := time.Now()

			// Create AWS V2 signature request
			req, err := http.NewRequest(scenario.Method, baseURL+"/test-bucket/test-object", nil)
			if err != nil {
				result.ErrorRequests++
				continue
			}

			// Add AWS Authorization header
			signature := createAWSV2Signature(key.SecretKey, scenario.Method, "/test-bucket/test-object")
			req.Header.Set("Authorization", fmt.Sprintf("AWS %s:%s", key.AccessKey, signature))
			req.Header.Set("Date", time.Now().UTC().Format(http.TimeFormat))

			resp, err := client.Do(req)
			reqLatency := time.Since(reqStart)
			latencies = append(latencies, reqLatency)

			result.TotalRequests++

			if err != nil {
				result.ErrorRequests++
				continue
			}

			resp.Body.Close()

			switch resp.StatusCode {
			case 200, 404: // 404 is OK from MinIO for non-existent objects
				result.SuccessfulRequests++
			case 429:
				result.RateLimitedRequests++
			default:
				if resp.StatusCode >= 400 && resp.StatusCode < 500 {
					result.SuccessfulRequests++ // Client errors are "successful" from rate limiting perspective
				} else {
					result.ErrorRequests++
				}
			}
		}
	}

	// Calculate statistics
	result.ActualDuration = time.Since(startTime)
	if len(latencies) > 0 {
		var totalLatency time.Duration
		result.MinLatency = latencies[0]
		result.MaxLatency = latencies[0]

		for _, latency := range latencies {
			totalLatency += latency
			if latency < result.MinLatency {
				result.MinLatency = latency
			}
			if latency > result.MaxLatency {
				result.MaxLatency = latency
			}
		}

		result.AverageLatency = totalLatency / time.Duration(len(latencies))
	}

	result.RequestsPerSecond = float64(result.TotalRequests) / result.ActualDuration.Seconds()

	return result
}

// createAWSV2Signature creates a simplified AWS V2 signature for testing
func createAWSV2Signature(secretKey, method, path string) string {
	stringToSign := method + "\n\n\n" + time.Now().UTC().Format(http.TimeFormat) + "\n" + path

	h := hmac.New(sha256.New, []byte(secretKey))
	h.Write([]byte(stringToSign))

	return hex.EncodeToString(h.Sum(nil))[:20] // Simplified signature
}

// generateReport creates a comprehensive test report
func generateReport(results []TestResult) {
	fmt.Println()
	color.Cyan("📊 COMPREHENSIVE TEST RESULTS")
	color.Cyan("==============================")
	fmt.Println()

	// Group results by scenario
	scenarioGroups := make(map[string][]TestResult)
	for _, result := range results {
		scenarioGroups[result.Scenario] = append(scenarioGroups[result.Scenario], result)
	}

	// Generate scenario summaries
	for scenario, results := range scenarioGroups {
		generateScenarioReport(scenario, results)
		fmt.Println()
	}

	// Generate overall summary
	generateOverallSummary(results)

	// Generate group comparison
	generateGroupComparison(results)

	// Generate performance metrics
	generatePerformanceReport(results)
}

// generateScenarioReport creates a report for a specific scenario
func generateScenarioReport(scenarioName string, results []TestResult) {
	color.Yellow("📋 Scenario: %s", scenarioName)
	color.Yellow(strings.Repeat("=", len(scenarioName)+12))

	table := tablewriter.NewWriter(os.Stdout)
	table.SetHeader([]string{"API Key", "Group", "Total", "Success", "Rate Limited", "Errors", "Avg Latency", "RPS"})
	table.SetBorder(true)

	var totalRequests, totalSuccess, totalRateLimited, totalErrors int
	var totalLatency time.Duration
	var totalRPS float64

	for _, result := range results {
		table.Append([]string{
			result.APIKey[:12] + "...",
			result.Group,
			strconv.Itoa(result.TotalRequests),
			strconv.Itoa(result.SuccessfulRequests),
			strconv.Itoa(result.RateLimitedRequests),
			strconv.Itoa(result.ErrorRequests),
			fmt.Sprintf("%.2fms", float64(result.AverageLatency.Nanoseconds())/1e6),
			fmt.Sprintf("%.2f", result.RequestsPerSecond),
		})

		totalRequests += result.TotalRequests
		totalSuccess += result.SuccessfulRequests
		totalRateLimited += result.RateLimitedRequests
		totalErrors += result.ErrorRequests
		totalLatency += result.AverageLatency
		totalRPS += result.RequestsPerSecond
	}

	table.Render()

	// Scenario summary
	successRate := float64(totalSuccess) / float64(totalRequests) * 100
	rateLimitRate := float64(totalRateLimited) / float64(totalRequests) * 100

	fmt.Printf("Summary: %d total requests, %.1f%% success, %.1f%% rate limited, %.1f%% errors\n",
		totalRequests, successRate, rateLimitRate, float64(totalErrors)/float64(totalRequests)*100)
}

// generateOverallSummary creates an overall test summary
func generateOverallSummary(results []TestResult) {
	color.Cyan("🎯 OVERALL TEST SUMMARY")
	color.Cyan("=======================")

	var totalRequests, totalSuccess, totalRateLimited, totalErrors int
	groupStats := make(map[string]struct {
		requests    int
		success     int
		rateLimited int
		errors      int
	})

	for _, result := range results {
		totalRequests += result.TotalRequests
		totalSuccess += result.SuccessfulRequests
		totalRateLimited += result.RateLimitedRequests
		totalErrors += result.ErrorRequests

		stats := groupStats[result.Group]
		stats.requests += result.TotalRequests
		stats.success += result.SuccessfulRequests
		stats.rateLimited += result.RateLimitedRequests
		stats.errors += result.ErrorRequests
		groupStats[result.Group] = stats
	}

	table := tablewriter.NewWriter(os.Stdout)
	table.SetHeader([]string{"Metric", "Value", "Percentage"})
	table.SetBorder(true)

	table.Append([]string{"Total Requests", strconv.Itoa(totalRequests), "100.0%"})
	table.Append([]string{"Successful Requests", strconv.Itoa(totalSuccess),
		fmt.Sprintf("%.1f%%", float64(totalSuccess)/float64(totalRequests)*100)})
	table.Append([]string{"Rate Limited", strconv.Itoa(totalRateLimited),
		fmt.Sprintf("%.1f%%", float64(totalRateLimited)/float64(totalRequests)*100)})
	table.Append([]string{"Error Requests", strconv.Itoa(totalErrors),
		fmt.Sprintf("%.1f%%", float64(totalErrors)/float64(totalRequests)*100)})

	table.Render()
	fmt.Println()
}

// generateGroupComparison compares performance across groups
func generateGroupComparison(results []TestResult) {
	color.Cyan("🏆 GROUP PERFORMANCE COMPARISON")
	color.Cyan("===============================")

	groupStats := make(map[string]struct {
		totalRequests   int
		successRequests int
		rateLimited     int
		avgLatency      time.Duration
		totalRPS        float64
		apiKeyCount     int
	})

	for _, result := range results {
		stats := groupStats[result.Group]
		stats.totalRequests += result.TotalRequests
		stats.successRequests += result.SuccessfulRequests
		stats.rateLimited += result.RateLimitedRequests
		stats.avgLatency += result.AverageLatency
		stats.totalRPS += result.RequestsPerSecond
		stats.apiKeyCount++
		groupStats[result.Group] = stats
	}

	table := tablewriter.NewWriter(os.Stdout)
	table.SetHeader([]string{"Group", "API Keys", "Total Requests", "Success Rate", "Rate Limited", "Avg Latency", "Avg RPS"})
	table.SetBorder(true)

	// Sort groups by name for consistent output
	var groupNames []string
	for group := range groupStats {
		groupNames = append(groupNames, group)
	}
	sort.Strings(groupNames)

	for _, group := range groupNames {
		stats := groupStats[group]
		successRate := float64(stats.successRequests) / float64(stats.totalRequests) * 100
		avgLatency := stats.avgLatency / time.Duration(stats.apiKeyCount)
		avgRPS := stats.totalRPS / float64(stats.apiKeyCount)

		table.Append([]string{
			strings.ToUpper(group),
			strconv.Itoa(stats.apiKeyCount),
			strconv.Itoa(stats.totalRequests),
			fmt.Sprintf("%.1f%%", successRate),
			strconv.Itoa(stats.rateLimited),
			fmt.Sprintf("%.2fms", float64(avgLatency.Nanoseconds())/1e6),
			fmt.Sprintf("%.2f", avgRPS),
		})
	}

	table.Render()
	fmt.Println()
}

// generatePerformanceReport creates a performance analysis report
func generatePerformanceReport(results []TestResult) {
	color.Cyan("⚡ PERFORMANCE ANALYSIS")
	color.Cyan("======================")

	var allLatencies []time.Duration
	var allRPS []float64

	for _, result := range results {
		allLatencies = append(allLatencies, result.AverageLatency)
		allRPS = append(allRPS, result.RequestsPerSecond)
	}

	sort.Slice(allLatencies, func(i, j int) bool {
		return allLatencies[i] < allLatencies[j]
	})
	sort.Float64s(allRPS)

	table := tablewriter.NewWriter(os.Stdout)
	table.SetHeader([]string{"Metric", "Min", "Max", "Median", "Average"})
	table.SetBorder(true)

	// Latency statistics
	minLatency := allLatencies[0]
	maxLatency := allLatencies[len(allLatencies)-1]
	medianLatency := allLatencies[len(allLatencies)/2]

	var totalLatency time.Duration
	for _, lat := range allLatencies {
		totalLatency += lat
	}
	avgLatency := totalLatency / time.Duration(len(allLatencies))

	table.Append([]string{
		"Latency (ms)",
		fmt.Sprintf("%.2f", float64(minLatency.Nanoseconds())/1e6),
		fmt.Sprintf("%.2f", float64(maxLatency.Nanoseconds())/1e6),
		fmt.Sprintf("%.2f", float64(medianLatency.Nanoseconds())/1e6),
		fmt.Sprintf("%.2f", float64(avgLatency.Nanoseconds())/1e6),
	})

	// RPS statistics
	minRPS := allRPS[0]
	maxRPS := allRPS[len(allRPS)-1]
	medianRPS := allRPS[len(allRPS)/2]

	var totalRPS float64
	for _, rps := range allRPS {
		totalRPS += rps
	}
	avgRPS := totalRPS / float64(len(allRPS))

	table.Append([]string{
		"Requests/Sec",
		fmt.Sprintf("%.2f", minRPS),
		fmt.Sprintf("%.2f", maxRPS),
		fmt.Sprintf("%.2f", medianRPS),
		fmt.Sprintf("%.2f", avgRPS),
	})

	table.Render()

	// Rate limiting effectiveness
	fmt.Println()
	color.Yellow("📈 Rate Limiting Effectiveness:")

	groupLimits := map[string]int{
		"premium":  1000,
		"standard": 500,
		"basic":    100,
	}

	for group, limit := range groupLimits {
		groupResults := filterResultsByGroup(results, group)
		if len(groupResults) > 0 {
			avgRequestsPerKey := calculateAverageRequests(groupResults)
			effectiveness := float64(limit-avgRequestsPerKey) / float64(limit) * 100

			if effectiveness > 0 {
				color.Green("  ✅ %s group: %.1f%% under limit (%d avg requests vs %d limit)",
					strings.Title(group), effectiveness, avgRequestsPerKey, limit)
			} else {
				color.Red("  ⚠️  %s group: %.1f%% over limit (%d avg requests vs %d limit)",
					strings.Title(group), -effectiveness, avgRequestsPerKey, limit)
			}
		}
	}

	fmt.Println()
}

// Helper functions
func filterResultsByGroup(results []TestResult, group string) []TestResult {
	var filtered []TestResult
	for _, result := range results {
		if result.Group == group {
			filtered = append(filtered, result)
		}
	}
	return filtered
}

func calculateAverageRequests(results []TestResult) int {
	if len(results) == 0 {
		return 0
	}

	total := 0
	for _, result := range results {
		total += result.TotalRequests
	}

	return total / len(results)
}
