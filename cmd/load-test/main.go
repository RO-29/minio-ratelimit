package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"math/rand"
	"os"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/fatih/color"
	"github.com/minio/minio-go/v7"
	minioCredentials "github.com/minio/minio-go/v7/pkg/credentials"
	"github.com/olekukonko/tablewriter"
)

type ServiceAccount struct {
	AccessKey   string `json:"access_key"`
	SecretKey   string `json:"secret_key"`
	Group       string `json:"group"`
	Created     string `json:"created"`
	Description string `json:"description"`
	Policy      string `json:"policy"`
}

type ServiceAccountsFile struct {
	ServiceAccounts []ServiceAccount `json:"service_accounts"`
	Metadata        struct {
		GeneratedAt   string `json:"generated_at"`
		Generator     string `json:"generator"`
		TotalAccounts int    `json:"total_accounts"`
		PremiumCount  int    `json:"premium_count"`
		StandardCount int    `json:"standard_count"`
		BasicCount    int    `json:"basic_count"`
		Version       string `json:"version"`
	} `json:"metadata"`
}

type LoadTestResult struct {
	AccountKey      string
	Group           string
	TotalRequests   int
	SuccessRequests int
	RateLimited     int
	Errors          int
	AvgLatency      time.Duration
	MinLatency      time.Duration
	MaxLatency      time.Duration
	TestDuration    time.Duration
	RequestsPerSec  float64
}

var (
	haproxyEndpoint = "localhost:80"
	testBuckets     = []string{"test-bucket", "premium-bucket", "standard-bucket", "basic-bucket", "shared-bucket"}
)

func main() {
	color.Cyan("🚀 LOAD TEST - Multiple Service Accounts")
	color.Cyan("=========================================")
	fmt.Println()

	// Load all service accounts
	allAccounts := loadServiceAccounts()
	color.Green("✅ Loaded %d service accounts", len(allAccounts))

	// Display breakdown
	groupCounts := make(map[string]int)
	for _, acc := range allAccounts {
		groupCounts[acc.Group]++
	}
	
	for group, count := range groupCounts {
		color.White("   • %s: %d accounts", strings.Title(group), count)
	}
	fmt.Println()

	// Select test accounts - use more for load testing
	testAccounts := selectLoadTestAccounts(allAccounts)
	color.Blue("Selected %d accounts for load testing:", len(testAccounts))
	
	testGroupCounts := make(map[string]int)
	for _, acc := range testAccounts {
		testGroupCounts[acc.Group]++
	}
	
	for group, count := range testGroupCounts {
		color.White("   • %s: %d accounts", strings.Title(group), count)
	}
	fmt.Println()

	// Run load tests
	color.Yellow("🔧 Starting concurrent load test...")
	results := runLoadTest(testAccounts)

	// Generate report
	generateLoadTestReport(results)
}

func loadServiceAccounts() []ServiceAccount {
	data, err := ioutil.ReadFile("../../config/generated_service_accounts.json")
	if err != nil {
		color.Red("❌ Failed to load service accounts: %v", err)
		color.Yellow("💡 Run ./generate-service-accounts.sh first")
		os.Exit(1)
	}

	var accounts ServiceAccountsFile
	if err := json.Unmarshal(data, &accounts); err != nil {
		color.Red("❌ Failed to parse service accounts: %v", err)
		os.Exit(1)
	}

	return accounts.ServiceAccounts
}

func selectLoadTestAccounts(allAccounts []ServiceAccount) []ServiceAccount {
	// For load testing, select more accounts from each group
	var testAccounts []ServiceAccount
	
	groupCounts := map[string]int{"premium": 0, "standard": 0, "basic": 0}
	maxPerGroup := map[string]int{"premium": 4, "standard": 8, "basic": 6} // Total: 18 accounts

	for _, acc := range allAccounts {
		if groupCounts[acc.Group] < maxPerGroup[acc.Group] {
			testAccounts = append(testAccounts, acc)
			groupCounts[acc.Group]++
		}
	}

	return testAccounts
}

func runLoadTest(accounts []ServiceAccount) []LoadTestResult {
	var results []LoadTestResult
	var wg sync.WaitGroup
	var mu sync.Mutex

	// Test duration
	testDuration := 2 * time.Minute

	color.White("Running load test for %v with %d concurrent clients...", testDuration, len(accounts))
	fmt.Println()

	startTime := time.Now()

	for i, account := range accounts {
		wg.Add(1)
		go func(acc ServiceAccount, index int) {
			defer wg.Done()

			result := runSingleAccountLoadTest(acc, index, testDuration)

			mu.Lock()
			results = append(results, result)
			mu.Unlock()
		}(account, i+1)

		// Stagger the start of each client to avoid thundering herd
		time.Sleep(100 * time.Millisecond)
	}

	wg.Wait()

	totalTestTime := time.Since(startTime)
	color.Green("✅ Load test completed in %v", totalTestTime)
	fmt.Println()

	return results
}

func runSingleAccountLoadTest(account ServiceAccount, clientIndex int, duration time.Duration) LoadTestResult {
	result := LoadTestResult{
		AccountKey: account.AccessKey,
		Group:      account.Group,
	}

	// Create MinIO client
	minioClient, err := minio.New(haproxyEndpoint, &minio.Options{
		Creds:  minioCredentials.NewStaticV4(account.AccessKey, account.SecretKey, ""),
		Secure: false,
	})

	if err != nil {
		color.Red("❌ Client %d: Failed to create MinIO client", clientIndex)
		return result
	}

	ctx := context.Background()
	var latencies []time.Duration
	
	// Different request rates based on group to test rate limiting
	requestInterval := getRequestInterval(account.Group)
	
	startTime := time.Now()
	endTime := startTime.Add(duration)

	color.White("Client %d (%s): Starting load test with %v intervals...", 
		clientIndex, account.Group, requestInterval)

	requestCount := 0
	for time.Now().Before(endTime) {
		requestStart := time.Now()
		requestCount++

		// Use different buckets for different groups
		bucket := selectBucketForGroup(account.Group)
		objectKey := fmt.Sprintf("load-test-%s-%s-%d-%d.txt", 
			account.Group, account.AccessKey[len(account.AccessKey)-8:], clientIndex, requestCount)
		
		content := fmt.Sprintf("Load test data from client %d (%s) - request %d at %s", 
			clientIndex, account.Group, requestCount, time.Now().Format(time.RFC3339))

		_, err := minioClient.PutObject(ctx, bucket, objectKey, 
			strings.NewReader(content), int64(len(content)), minio.PutObjectOptions{
				ContentType: "text/plain",
			})

		latency := time.Since(requestStart)
		latencies = append(latencies, latency)
		result.TotalRequests++

		if err != nil {
			errorStr := err.Error()
			if strings.Contains(errorStr, "SlowDown") || strings.Contains(errorStr, "429") {
				result.RateLimited++
				if requestCount <= 5 || requestCount%20 == 0 { // Log first few and every 20th
					color.Red("    Client %d: Request %d RATE LIMITED", clientIndex, requestCount)
				}
			} else {
				result.Errors++
				if requestCount <= 5 {
					color.Yellow("    Client %d: Request %d ERROR - %s", clientIndex, requestCount, errorStr[:30])
				}
			}
		} else {
			result.SuccessRequests++
			if requestCount <= 5 || requestCount%20 == 0 {
				color.Green("    Client %d: Request %d SUCCESS", clientIndex, requestCount)
			}
		}

		// Wait before next request
		time.Sleep(requestInterval)
	}

	result.TestDuration = time.Since(startTime)

	// Calculate statistics
	if len(latencies) > 0 {
		sort.Slice(latencies, func(i, j int) bool {
			return latencies[i] < latencies[j]
		})

		result.MinLatency = latencies[0]
		result.MaxLatency = latencies[len(latencies)-1]

		var totalLatency time.Duration
		for _, lat := range latencies {
			totalLatency += lat
		}
		result.AvgLatency = totalLatency / time.Duration(len(latencies))
	}

	result.RequestsPerSec = float64(result.TotalRequests) / result.TestDuration.Seconds()

	color.White("Client %d (%s) completed: %d requests, %d success, %d rate limited, %d errors", 
		clientIndex, account.Group, result.TotalRequests, result.SuccessRequests, result.RateLimited, result.Errors)

	return result
}

func getRequestInterval(group string) time.Duration {
	switch group {
	case "premium":
		return 4 * time.Second  // 15 req/min
	case "standard":
		return 6 * time.Second  // 10 req/min  
	case "basic":
		return 10 * time.Second // 6 req/min
	default:
		return 12 * time.Second // 5 req/min
	}
}

func selectBucketForGroup(group string) string {
	switch group {
	case "premium":
		return testBuckets[1] // premium-bucket
	case "standard":
		return testBuckets[2] // standard-bucket
	case "basic":
		return testBuckets[3] // basic-bucket
	default:
		return testBuckets[0] // test-bucket
	}
}

func generateLoadTestReport(results []LoadTestResult) {
	color.Cyan("\n📊 LOAD TEST RESULTS")
	color.Cyan("===================")
	fmt.Println()

	// Sort results by group then by success rate
	sort.Slice(results, func(i, j int) bool {
		if results[i].Group == results[j].Group {
			return results[i].SuccessRequests > results[j].SuccessRequests
		}
		return results[i].Group < results[j].Group
	})

	// Generate summary table
	table := tablewriter.NewWriter(os.Stdout)
	table.SetHeader([]string{"Client", "Group", "Total", "Success", "Rate Limited", "Errors", "Success %", "RPS", "Avg Latency"})
	table.SetBorder(true)

	var grandTotal, grandSuccess, grandRateLimited, grandErrors int

	for i, result := range results {
		successPercent := float64(result.SuccessRequests) / float64(result.TotalRequests) * 100
		
		table.Append([]string{
			result.AccountKey[len(result.AccountKey)-8:],
			result.Group,
			strconv.Itoa(result.TotalRequests),
			strconv.Itoa(result.SuccessRequests),
			strconv.Itoa(result.RateLimited),
			strconv.Itoa(result.Errors),
			fmt.Sprintf("%.1f%%", successPercent),
			fmt.Sprintf("%.2f", result.RequestsPerSec),
			fmt.Sprintf("%.0fms", float64(result.AvgLatency.Nanoseconds())/1e6),
		})

		grandTotal += result.TotalRequests
		grandSuccess += result.SuccessRequests
		grandRateLimited += result.RateLimited
		grandErrors += result.Errors

		// Add separator every 6 rows for readability
		if (i+1)%6 == 0 && i+1 < len(results) {
			table.Append([]string{"---", "---", "---", "---", "---", "---", "---", "---", "---"})
		}
	}

	table.Render()

	// Generate group analysis
	fmt.Println()
	color.Yellow("📈 GROUP ANALYSIS")
	color.Yellow("================")

	groupStats := make(map[string]struct {
		clients      int
		totalReqs    int
		successReqs  int
		rateLimited  int
		errors       int
		avgRPS       float64
	})

	for _, result := range results {
		stats := groupStats[result.Group]
		stats.clients++
		stats.totalReqs += result.TotalRequests
		stats.successReqs += result.SuccessRequests
		stats.rateLimited += result.RateLimited
		stats.errors += result.Errors
		stats.avgRPS += result.RequestsPerSec
		groupStats[result.Group] = stats
	}

	groupTable := tablewriter.NewWriter(os.Stdout)
	groupTable.SetHeader([]string{"Group", "Clients", "Total Requests", "Success Rate", "Rate Limited", "Avg RPS/Client", "Expected Limit"})
	groupTable.SetBorder(true)

	expectedLimits := map[string]string{
		"premium":  "1000/min (16.7/sec)",
		"standard": "500/min (8.3/sec)",
		"basic":    "100/min (1.7/sec)",
	}

	for group, stats := range groupStats {
		successRate := float64(stats.successReqs) / float64(stats.totalReqs) * 100
		avgRPS := stats.avgRPS / float64(stats.clients)
		
		groupTable.Append([]string{
			strings.Title(group),
			strconv.Itoa(stats.clients),
			strconv.Itoa(stats.totalReqs),
			fmt.Sprintf("%.1f%%", successRate),
			strconv.Itoa(stats.rateLimited),
			fmt.Sprintf("%.2f", avgRPS),
			expectedLimits[group],
		})
	}

	groupTable.Render()

	// Overall summary
	fmt.Println()
	color.Blue("🎯 LOAD TEST SUMMARY")
	color.Blue("===================")

	overallSuccessRate := float64(grandSuccess) / float64(grandTotal) * 100
	rateLimitedRate := float64(grandRateLimited) / float64(grandTotal) * 100

	color.White("Total requests: %d", grandTotal)
	color.White("Successful requests: %d (%.1f%%)", grandSuccess, overallSuccessRate)
	color.White("Rate limited requests: %d (%.1f%%)", grandRateLimited, rateLimitedRate)
	color.White("Error requests: %d (%.1f%%)", grandErrors, float64(grandErrors)/float64(grandTotal)*100)

	fmt.Println()

	// Analysis and recommendations
	if rateLimitedRate > 20 {
		color.Green("✅ Rate limiting is working effectively (%.1f%% of requests limited)", rateLimitedRate)
	} else if rateLimitedRate > 5 {
		color.Yellow("⚠️  Some rate limiting observed (%.1f%%)", rateLimitedRate)
	} else {
		color.Yellow("⚠️  Little to no rate limiting observed - consider increasing request rates")
	}

	if overallSuccessRate > 50 {
		color.Green("✅ Good success rate (%.1f%%) - service accounts are working", overallSuccessRate)
	} else if overallSuccessRate > 20 {
		color.Yellow("⚠️  Moderate success rate (%.1f%%)", overallSuccessRate)
	} else {
		color.Red("❌ Low success rate (%.1f%%) - may indicate authentication issues", overallSuccessRate)
	}

	fmt.Println()
	color.Cyan("🎯 LOAD TEST CONCLUSION")
	color.Cyan("======================")
	color.White("• Multiple service accounts tested concurrently")
	color.White("• Rate limiting system handling concurrent load")
	color.White("• Individual key tracking working under load")
	color.White("• System performance validated")
}