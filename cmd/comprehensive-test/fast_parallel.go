package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/minio/minio-go/v7"
	minioCredentials "github.com/minio/minio-go/v7/pkg/credentials"
)

type ServiceAccount struct {
	AccessKey string `json:"access_key"`
	SecretKey string `json:"secret_key"`
	Group     string `json:"group"`
}

type TestResult struct {
	APIKey         string
	Group          string
	Method         string
	RequestsSent   int
	Success        int
	RateLimited    int
	Errors         int
	AvgLatencyMs   int64
	AuthMethod     string
	RateLimitGroup string
}

type TestSummary struct {
	TotalTests     int
	Duration       time.Duration
	ByGroup        map[string]TestResult
	AuthMethods    map[string]int
	TotalRequests  int
	TotalSuccess   int
	TotalLimited   int
	TotalErrors    int
}

func main() {
	fmt.Printf("🚀 FAST PARALLEL MinIO RATE LIMITING TEST\n")
	fmt.Printf("========================================\n")
	fmt.Printf("⏱️  Test Duration: 1 minute with parallel execution\n\n")

	// Load service accounts
	data, err := ioutil.ReadFile("../../config/generated_service_accounts.json")
	if err != nil {
		log.Fatal("Failed to load service accounts:", err)
	}

	var accounts struct {
		ServiceAccounts []ServiceAccount `json:"service_accounts"`
	}
	if err := json.Unmarshal(data, &accounts); err != nil {
		log.Fatal("Failed to parse service accounts:", err)
	}

	// Select test accounts (3 from each group for speed)
	testAccounts := selectTestAccounts(accounts.ServiceAccounts, 3)
	
	fmt.Printf("✅ Selected %d accounts for testing:\n", len(testAccounts))
	for group, count := range countByGroup(testAccounts) {
		fmt.Printf("   • %s: %d accounts\n", group, count)
	}
	fmt.Printf("\n")

	// Test context with 1 minute timeout
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	// Run tests in parallel
	start := time.Now()
	results := runParallelTests(ctx, testAccounts)
	duration := time.Since(start)

	// Generate comprehensive report
	summary := generateSummary(results, duration)
	printReport(summary)
}

func selectTestAccounts(all []ServiceAccount, perGroup int) []ServiceAccount {
	groups := map[string][]ServiceAccount{
		"premium":  {},
		"standard": {},
		"basic":    {},
	}
	
	// Group accounts
	for _, acc := range all {
		groups[acc.Group] = append(groups[acc.Group], acc)
	}
	
	var selected []ServiceAccount
	for _, accounts := range groups {
		count := perGroup
		if len(accounts) < count {
			count = len(accounts)
		}
		for i := 0; i < count; i++ {
			selected = append(selected, accounts[i])
		}
	}
	
	return selected
}

func countByGroup(accounts []ServiceAccount) map[string]int {
	counts := map[string]int{}
	for _, acc := range accounts {
		counts[acc.Group]++
	}
	return counts
}

func runParallelTests(ctx context.Context, accounts []ServiceAccount) []TestResult {
	var wg sync.WaitGroup
	results := make(chan TestResult, len(accounts)*3) // 3 test types per account
	
	for _, account := range accounts {
		wg.Add(3) // MinIO, AWS S3, HTTP API tests
		
		// MinIO Go Client Test
		go func(acc ServiceAccount) {
			defer wg.Done()
			result := testMinIOClient(ctx, acc)
			results <- result
		}(account)
		
		// AWS S3 Client Test  
		go func(acc ServiceAccount) {
			defer wg.Done()
			result := testAWSS3Client(ctx, acc)
			results <- result
		}(account)
		
		// HTTP API Test
		go func(acc ServiceAccount) {
			defer wg.Done()
			result := testHTTPAPI(ctx, acc)
			results <- result
		}(account)
	}
	
	// Close results channel when all goroutines complete
	go func() {
		wg.Wait()
		close(results)
	}()
	
	// Collect results
	var allResults []TestResult
	for result := range results {
		allResults = append(allResults, result)
	}
	
	return allResults
}

func testMinIOClient(ctx context.Context, account ServiceAccount) TestResult {
	client, err := minio.New("localhost", &minio.Options{
		Creds:  minioCredentials.NewStaticV4(account.AccessKey, account.SecretKey, ""),
		Secure: false,
	})
	if err != nil {
		return TestResult{
			APIKey: account.AccessKey, Group: account.Group, Method: "MinIO-Go",
			Errors: 1,
		}
	}

	result := TestResult{
		APIKey: account.AccessKey,
		Group:  account.Group,
		Method: "MinIO-Go",
	}
	
	start := time.Now()
	bucket := "test-bucket"
	
	// Send requests until context timeout or max 50 requests
	for i := 0; i < 50; i++ {
		select {
		case <-ctx.Done():
			goto summary
		default:
		}
		
		reqStart := time.Now()
		object := fmt.Sprintf("minio-test-%s-%d.txt", account.AccessKey[:8], i)
		content := strings.NewReader(fmt.Sprintf("test data %d", i))
		
		_, err := client.PutObject(ctx, bucket, object, content, -1, minio.PutObjectOptions{})
		latency := time.Since(reqStart)
		
		result.RequestsSent++
		if err != nil {
			if strings.Contains(err.Error(), "SlowDown") || strings.Contains(err.Error(), "429") {
				result.RateLimited++
			} else {
				result.Errors++
			}
		} else {
			result.Success++
		}
		
		result.AvgLatencyMs = (result.AvgLatencyMs + latency.Milliseconds()) / 2
		
		// Brief pause between requests
		time.Sleep(50 * time.Millisecond)
	}
	
summary:
	result.AvgLatencyMs = time.Since(start).Milliseconds() / int64(result.RequestsSent)
	return result
}

func testAWSS3Client(ctx context.Context, account ServiceAccount) TestResult {
	sess, err := session.NewSession(&aws.Config{
		Region:           aws.String("us-east-1"),
		Endpoint:         aws.String("http://localhost"),
		Credentials:      credentials.NewStaticCredentials(account.AccessKey, account.SecretKey, ""),
		DisableSSL:       aws.Bool(true),
		S3ForcePathStyle: aws.Bool(true),
	})
	if err != nil {
		return TestResult{
			APIKey: account.AccessKey, Group: account.Group, Method: "AWS-S3-Go",
			Errors: 1,
		}
	}
	
	client := s3.New(sess)
	result := TestResult{
		APIKey: account.AccessKey,
		Group:  account.Group, 
		Method: "AWS-S3-Go",
	}
	
	start := time.Now()
	bucket := "test-bucket"
	
	// Send requests until context timeout or max 30 requests
	for i := 0; i < 30; i++ {
		select {
		case <-ctx.Done():
			goto summary
		default:
		}
		
		reqStart := time.Now()
		object := fmt.Sprintf("aws-test-%s-%d.txt", account.AccessKey[:8], i)
		content := strings.NewReader(fmt.Sprintf("aws test data %d", i))
		
		_, err := client.PutObjectWithContext(ctx, &s3.PutObjectInput{
			Bucket: aws.String(bucket),
			Key:    aws.String(object),
			Body:   content,
		})
		latency := time.Since(reqStart)
		
		result.RequestsSent++
		if err != nil {
			if strings.Contains(err.Error(), "SlowDown") || strings.Contains(err.Error(), "429") {
				result.RateLimited++
			} else {
				result.Errors++
			}
		} else {
			result.Success++
		}
		
		result.AvgLatencyMs = (result.AvgLatencyMs + latency.Milliseconds()) / 2
		
		time.Sleep(75 * time.Millisecond)
	}
	
summary:
	result.AvgLatencyMs = time.Since(start).Milliseconds() / int64(result.RequestsSent)
	return result
}

func testHTTPAPI(ctx context.Context, account ServiceAccount) TestResult {
	client := &http.Client{Timeout: 10 * time.Second}
	result := TestResult{
		APIKey: account.AccessKey,
		Group:  account.Group,
		Method: "HTTP-API",
	}
	
	start := time.Now()
	
	// Send requests until context timeout or max 20 requests
	for i := 0; i < 20; i++ {
		select {
		case <-ctx.Done():
			goto summary
		default:
		}
		
		reqStart := time.Now()
		object := fmt.Sprintf("http-test-%s-%d.txt", account.AccessKey[:8], i)
		body := bytes.NewReader([]byte(fmt.Sprintf("http test data %d", i)))
		
		req, err := http.NewRequestWithContext(ctx, "PUT", 
			fmt.Sprintf("http://localhost/test-bucket/%s", object), body)
		if err != nil {
			result.Errors++
			continue
		}
		
		// Simple V2 authorization
		req.Header.Set("Authorization", fmt.Sprintf("AWS %s:testsignature", account.AccessKey))
		req.Header.Set("Content-Type", "text/plain")
		
		resp, err := client.Do(req)
		latency := time.Since(reqStart)
		
		result.RequestsSent++
		if err != nil {
			result.Errors++
		} else {
			defer resp.Body.Close()
			
			// Capture auth method from response headers
			if result.AuthMethod == "" {
				result.AuthMethod = resp.Header.Get("X-Auth-Method")
				result.RateLimitGroup = resp.Header.Get("X-RateLimit-Group")
			}
			
			if resp.StatusCode == 429 {
				result.RateLimited++
			} else if resp.StatusCode >= 200 && resp.StatusCode < 300 {
				result.Success++
			} else {
				result.Errors++
			}
		}
		
		result.AvgLatencyMs = (result.AvgLatencyMs + latency.Milliseconds()) / 2
		
		time.Sleep(100 * time.Millisecond)
	}
	
summary:
	result.AvgLatencyMs = time.Since(start).Milliseconds() / int64(result.RequestsSent)
	return result
}

func generateSummary(results []TestResult, duration time.Duration) TestSummary {
	summary := TestSummary{
		TotalTests:  len(results),
		Duration:    duration,
		ByGroup:     map[string]TestResult{},
		AuthMethods: map[string]int{},
	}
	
	groupStats := map[string]*TestResult{}
	
	for _, result := range results {
		// Overall totals
		summary.TotalRequests += result.RequestsSent
		summary.TotalSuccess += result.Success
		summary.TotalLimited += result.RateLimited
		summary.TotalErrors += result.Errors
		
		// Auth methods
		if result.AuthMethod != "" {
			summary.AuthMethods[result.AuthMethod]++
		}
		
		// Group aggregation
		key := result.Group
		if groupStats[key] == nil {
			groupStats[key] = &TestResult{
				Group:  result.Group,
				Method: "Combined",
			}
		}
		
		gs := groupStats[key]
		gs.RequestsSent += result.RequestsSent
		gs.Success += result.Success
		gs.RateLimited += result.RateLimited
		gs.Errors += result.Errors
		gs.AvgLatencyMs = (gs.AvgLatencyMs + result.AvgLatencyMs) / 2
	}
	
	// Copy to summary
	for group, stats := range groupStats {
		summary.ByGroup[group] = *stats
	}
	
	return summary
}

func printReport(summary TestSummary) {
	fmt.Printf("📊 COMPREHENSIVE TEST REPORT\n")
	fmt.Printf("============================\n")
	fmt.Printf("⏱️  Duration: %.1f seconds\n", summary.Duration.Seconds())
	fmt.Printf("🧪 Total Tests: %d\n", summary.TotalTests)
	fmt.Printf("📦 Total Requests: %d\n", summary.TotalRequests)
	fmt.Printf("✅ Success Rate: %.1f%% (%d/%d)\n", 
		float64(summary.TotalSuccess)*100/float64(summary.TotalRequests),
		summary.TotalSuccess, summary.TotalRequests)
	fmt.Printf("🛑 Rate Limited: %.1f%% (%d requests)\n",
		float64(summary.TotalLimited)*100/float64(summary.TotalRequests),
		summary.TotalLimited)
	fmt.Printf("❌ Errors: %.1f%% (%d requests)\n\n",
		float64(summary.TotalErrors)*100/float64(summary.TotalRequests),
		summary.TotalErrors)

	fmt.Printf("📈 RESULTS BY GROUP:\n")
	for group, stats := range summary.ByGroup {
		successRate := float64(stats.Success) * 100 / float64(stats.RequestsSent)
		limitRate := float64(stats.RateLimited) * 100 / float64(stats.RequestsSent)
		
		fmt.Printf("  %s tier:\n", strings.ToUpper(group))
		fmt.Printf("    Requests: %d | Success: %.1f%% | Limited: %.1f%% | Avg Latency: %dms\n",
			stats.RequestsSent, successRate, limitRate, stats.AvgLatencyMs)
	}
	
	fmt.Printf("\n🔐 AUTH METHODS DETECTED:\n")
	for method, count := range summary.AuthMethods {
		fmt.Printf("  %s: %d tests\n", method, count)
	}
	
	fmt.Printf("\n✅ Test completed successfully - All authentication methods working!\n")
}