package main

import (
	"bytes"
	"context"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/minio/minio-go/v7"
	minioCredentials "github.com/minio/minio-go/v7/pkg/credentials"
)

// runComprehensiveTests executes all test types for the given accounts
func runComprehensiveTests(ctx context.Context, accounts []ServiceAccount, progress *ProgressTracker) []TestResult {
	var wg sync.WaitGroup
	results := make(chan TestResult, len(accounts)*4) // 4 test types per account

	for _, account := range accounts {
		wg.Add(4) // MinIO, AWS S3, HTTP API, and Burst tests

		// MinIO Go Client Test with monitoring
		go func(acc ServiceAccount) {
			defer wg.Done()
			result := testMinIOClientEnhanced(ctx, acc, progress)
			results <- result
		}(account)

		// AWS S3 Client Test with monitoring
		go func(acc ServiceAccount) {
			defer wg.Done()
			result := testAWSS3ClientEnhanced(ctx, acc, progress)
			results <- result
		}(account)

		// HTTP API Test with header capture
		go func(acc ServiceAccount) {
			defer wg.Done()
			result := testHTTPAPIEnhanced(ctx, acc, progress)
			results <- result
		}(account)

		// Burst Test to test rate limits intensively
		go func(acc ServiceAccount) {
			defer wg.Done()
			result := testBurstRequests(ctx, acc, progress)
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

// runPremiumStressTests executes premium stress testing with higher load
func runPremiumStressTests(ctx context.Context, accounts []ServiceAccount, progress *ProgressTracker, config TestConfig) []TestResult {
	var wg sync.WaitGroup
	results := make(chan TestResult, len(accounts)*6) // More test types for stress testing

	for _, account := range accounts {
		if account.Group != "premium" {
			continue // Only test premium accounts in stress mode
		}

		wg.Add(6) // Multiple high-load test types

		// High-load HTTP API tests
		go func(acc ServiceAccount) {
			defer wg.Done()
			result := testPremiumStressHTTP(ctx, acc, progress)
			results <- result
		}(account)

		// Intensive burst testing
		go func(acc ServiceAccount) {
			defer wg.Done()
			result := testIntensiveBurst(ctx, acc, progress)
			results <- result
		}(account)

		// Sustained load testing
		go func(acc ServiceAccount) {
			defer wg.Done()
			result := testSustainedLoad(ctx, acc, progress)
			results <- result
		}(account)

		// Concurrent MinIO testing
		go func(acc ServiceAccount) {
			defer wg.Done()
			result := testMinIOClientEnhanced(ctx, acc, progress)
			results <- result
		}(account)

		// Concurrent AWS S3 testing
		go func(acc ServiceAccount) {
			defer wg.Done()
			result := testAWSS3ClientEnhanced(ctx, acc, progress)
			results <- result
		}(account)

		// Standard HTTP testing for comparison
		go func(acc ServiceAccount) {
			defer wg.Done()
			result := testHTTPAPIEnhanced(ctx, acc, progress)
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

// testMinIOClientEnhanced tests MinIO Go client with enhanced monitoring
func testMinIOClientEnhanced(ctx context.Context, account ServiceAccount, progress *ProgressTracker) TestResult {
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
		APIKey:         account.AccessKey,
		Group:          account.Group,
		Method:         "MinIO-Go",
		HeaderCaptures: make([]ResponseHeaders, 0),
		ErrorDetails:   make(map[string]int),
		ErrorExamples:  make([]ErrorExample, 0),
	}

	start := time.Now()
	bucket := "test-bucket"

	// Send requests until context timeout or max 75 requests for enhanced testing
	for i := 0; i < 75; i++ {
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
		atomic.AddInt64(&progress.totalRequests, 1)

		if err != nil {
			if strings.Contains(err.Error(), "SlowDown") || strings.Contains(err.Error(), "429") {
				result.RateLimited++
				atomic.AddInt64(&progress.rateLimitCount, 1)
			} else {
				result.Errors++
				atomic.AddInt64(&progress.errorCount, 1)
				// Categorize error for analysis
				errorType := categorizeError(err.Error(), 0)
				result.ErrorDetails[errorType]++
				if len(result.ErrorExamples) < 3 {
					result.ErrorExamples = append(result.ErrorExamples, ErrorExample{
						StatusCode: 0,
						Error:      err.Error(),
						Timestamp:  time.Now(),
						Method:     "MinIO-Go",
					})
				}
			}
		} else {
			result.Success++
			atomic.AddInt64(&progress.successCount, 1)
		}

		result.AvgLatencyMs = (result.AvgLatencyMs + latency.Milliseconds()) / 2

		// Dynamic pause based on success rate for adaptive testing
		if result.RateLimited > result.Success {
			time.Sleep(100 * time.Millisecond) // Slow down if being throttled
		} else {
			time.Sleep(25 * time.Millisecond) // Faster when successful
		}
	}

summary:
	if result.RequestsSent > 0 {
		result.AvgLatencyMs = time.Since(start).Milliseconds() / int64(result.RequestsSent)
	}
	return result
}

// testAWSS3ClientEnhanced tests AWS S3 Go client with enhanced monitoring
func testAWSS3ClientEnhanced(ctx context.Context, account ServiceAccount, progress *ProgressTracker) TestResult {
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
		APIKey:         account.AccessKey,
		Group:          account.Group,
		Method:         "AWS-S3-Go",
		HeaderCaptures: make([]ResponseHeaders, 0),
		ErrorDetails:   make(map[string]int),
		ErrorExamples:  make([]ErrorExample, 0),
	}

	start := time.Now()
	bucket := "test-bucket"

	// Send requests until context timeout or max 50 requests for enhanced testing
	for i := 0; i < 50; i++ {
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
		atomic.AddInt64(&progress.totalRequests, 1)

		if err != nil {
			if strings.Contains(err.Error(), "SlowDown") || strings.Contains(err.Error(), "429") {
				result.RateLimited++
				atomic.AddInt64(&progress.rateLimitCount, 1)
			} else {
				result.Errors++
				atomic.AddInt64(&progress.errorCount, 1)
			}
		} else {
			result.Success++
			atomic.AddInt64(&progress.successCount, 1)
		}

		result.AvgLatencyMs = (result.AvgLatencyMs + latency.Milliseconds()) / 2

		// Adaptive delay based on throttling
		if result.RateLimited > 0 && i > 5 {
			time.Sleep(120 * time.Millisecond)
		} else {
			time.Sleep(50 * time.Millisecond)
		}
	}

summary:
	if result.RequestsSent > 0 {
		result.AvgLatencyMs = time.Since(start).Milliseconds() / int64(result.RequestsSent)
	}
	return result
}

// testHTTPAPIEnhanced tests HTTP API with comprehensive header capture
func testHTTPAPIEnhanced(ctx context.Context, account ServiceAccount, progress *ProgressTracker) TestResult {
	client := &http.Client{Timeout: 15 * time.Second}
	result := TestResult{
		APIKey:         account.AccessKey,
		Group:          account.Group,
		Method:         "HTTP-API",
		HeaderCaptures: make([]ResponseHeaders, 0),
		ErrorDetails:   make(map[string]int),
		ErrorExamples:  make([]ErrorExample, 0),
	}

	start := time.Now()

	// Send requests until context timeout or max 40 requests for enhanced testing
	for i := 0; i < 40; i++ {
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
			atomic.AddInt64(&progress.errorCount, 1)
			continue
		}

		// Simple V2 authorization
		req.Header.Set("Authorization", fmt.Sprintf("AWS %s:testsignature", account.AccessKey))
		req.Header.Set("Content-Type", "text/plain")

		resp, err := client.Do(req)
		latency := time.Since(reqStart)

		result.RequestsSent++
		atomic.AddInt64(&progress.totalRequests, 1)

		if err != nil {
			result.Errors++
			atomic.AddInt64(&progress.errorCount, 1)
			// Categorize HTTP client error
			errorType := categorizeError(err.Error(), 0)
			result.ErrorDetails[errorType]++
			if len(result.ErrorExamples) < 3 {
				result.ErrorExamples = append(result.ErrorExamples, ErrorExample{
					StatusCode: 0,
					Error:      err.Error(),
					Timestamp:  time.Now(),
					Method:     "HTTP-API",
				})
			}
		} else {
			defer resp.Body.Close()

			// Comprehensive header capture for analysis
			headerCapture := ResponseHeaders{
				Timestamp:  time.Now(),
				StatusCode: resp.StatusCode,
				LatencyMs:  latency.Milliseconds(),
				Headers:    make(map[string]string),
			}

			// Capture important headers
			importantHeaders := []string{
				"X-Auth-Method", "X-Ratelimit-Group", "X-Ratelimit-Limit-Per-Second",
				"X-Ratelimit-Limit-Per-Minute", "X-Ratelimit-Remaining", "X-Ratelimit-Current-Per-Second",
				"X-Ratelimit-Current-Per-Minute", "X-Ratelimit-Reset", "X-Api-Key", "Date", "Server",
			}

			for _, header := range importantHeaders {
				if value := resp.Header.Get(header); value != "" {
					headerCapture.Headers[header] = value
				}
			}

			result.HeaderCaptures = append(result.HeaderCaptures, headerCapture)

			// Capture auth method and rate limit info from response headers
			if result.AuthMethod == "" {
				result.AuthMethod = resp.Header.Get("X-Auth-Method")
				result.RateLimitGroup = resp.Header.Get("X-Ratelimit-Group")

				// Parse rate limit details
				if limitStr := resp.Header.Get("X-Ratelimit-Limit-Per-Second"); limitStr != "" {
					if limit, err := strconv.ParseInt(limitStr, 10, 64); err == nil {
						result.RateLimitDetails.LimitPerSecond = limit
					}
				}
				if limitStr := resp.Header.Get("X-Ratelimit-Limit-Per-Minute"); limitStr != "" {
					if limit, err := strconv.ParseInt(limitStr, 10, 64); err == nil {
						result.RateLimitDetails.LimitPerMinute = limit
					}
				}
			}

			// Update current rate limit stats
			if currentStr := resp.Header.Get("X-Ratelimit-Current-Per-Second"); currentStr != "" {
				if current, err := strconv.ParseInt(currentStr, 10, 64); err == nil {
					result.RateLimitDetails.CurrentPerSecond = current
				}
			}
			if currentStr := resp.Header.Get("X-Ratelimit-Current-Per-Minute"); currentStr != "" {
				if current, err := strconv.ParseInt(currentStr, 10, 64); err == nil {
					result.RateLimitDetails.CurrentPerMinute = current
				}
			}

			if resp.StatusCode == 429 {
				result.RateLimited++
				atomic.AddInt64(&progress.rateLimitCount, 1)
			} else if resp.StatusCode >= 200 && resp.StatusCode < 300 {
				result.Success++
				atomic.AddInt64(&progress.successCount, 1)
			} else {
				result.Errors++
				atomic.AddInt64(&progress.errorCount, 1)
				// Categorize HTTP status error
				errorType := categorizeError("", resp.StatusCode)
				result.ErrorDetails[errorType]++
				if len(result.ErrorExamples) < 5 {
					result.ErrorExamples = append(result.ErrorExamples, ErrorExample{
						StatusCode: resp.StatusCode,
						Error:      fmt.Sprintf("HTTP %d %s", resp.StatusCode, http.StatusText(resp.StatusCode)),
						Timestamp:  time.Now(),
						Method:     "HTTP-API",
					})
				}
			}
		}

		result.AvgLatencyMs = (result.AvgLatencyMs + latency.Milliseconds()) / 2

		// Dynamic sleep based on rate limiting
		if len(result.HeaderCaptures) > 3 {
			lastCapture := result.HeaderCaptures[len(result.HeaderCaptures)-1]
			if lastCapture.StatusCode == 429 {
				time.Sleep(200 * time.Millisecond) // Slow down if throttled
			} else {
				time.Sleep(50 * time.Millisecond) // Faster when successful
			}
		} else {
			time.Sleep(75 * time.Millisecond)
		}
	}

summary:
	if result.RequestsSent > 0 {
		result.AvgLatencyMs = time.Since(start).Milliseconds() / int64(result.RequestsSent)
	}
	return result
}

// testBurstRequests performs burst testing to intensively test rate limits
func testBurstRequests(ctx context.Context, account ServiceAccount, progress *ProgressTracker) TestResult {
	client := &http.Client{Timeout: 5 * time.Second}
	result := TestResult{
		APIKey:         account.AccessKey,
		Group:          account.Group,
		Method:         "Burst-Test",
		HeaderCaptures: make([]ResponseHeaders, 0),
		ErrorDetails:   make(map[string]int),
		ErrorExamples:  make([]ErrorExample, 0),
	}

	start := time.Now()
	burstSize := 20 // Number of rapid requests

	// Burst test: send rapid consecutive requests to test rate limits
	for burst := 0; burst < 3; burst++ {
		select {
		case <-ctx.Done():
			goto summary
		default:
		}

		successInBurst := 0

		// Send burst of requests with minimal delay
		for i := 0; i < burstSize; i++ {
			select {
			case <-ctx.Done():
				goto summary
			default:
			}

			reqStart := time.Now()
			object := fmt.Sprintf("burst-test-%s-%d-%d.txt", account.AccessKey[:8], burst, i)
			body := bytes.NewReader([]byte(fmt.Sprintf("burst test data %d-%d", burst, i)))

			req, err := http.NewRequestWithContext(ctx, "PUT",
				fmt.Sprintf("http://localhost/test-bucket/%s", object), body)
			if err != nil {
				result.Errors++
				atomic.AddInt64(&progress.errorCount, 1)
				continue
			}

			req.Header.Set("Authorization", fmt.Sprintf("AWS %s:testsignature", account.AccessKey))
			req.Header.Set("Content-Type", "text/plain")

			resp, err := client.Do(req)
			latency := time.Since(reqStart)

			result.RequestsSent++
			atomic.AddInt64(&progress.totalRequests, 1)

			if err != nil {
				result.Errors++
				atomic.AddInt64(&progress.errorCount, 1)
			} else {
				defer resp.Body.Close()

				// Capture detailed burst headers
				headerCapture := ResponseHeaders{
					Timestamp:  time.Now(),
					StatusCode: resp.StatusCode,
					LatencyMs:  latency.Milliseconds(),
					Headers:    make(map[string]string),
				}

				// Capture all rate limit headers for burst analysis
				burstHeaders := []string{
					"X-Auth-Method", "X-Ratelimit-Group", "X-Ratelimit-Limit-Per-Second",
					"X-Ratelimit-Limit-Per-Minute", "X-Ratelimit-Remaining",
					"X-Ratelimit-Current-Per-Second", "X-Ratelimit-Current-Per-Minute",
					"X-Ratelimit-Reset", "Date",
				}

				for _, header := range burstHeaders {
					if value := resp.Header.Get(header); value != "" {
						headerCapture.Headers[header] = value
					}
				}

				result.HeaderCaptures = append(result.HeaderCaptures, headerCapture)

				if resp.StatusCode == 429 {
					result.RateLimited++
					atomic.AddInt64(&progress.rateLimitCount, 1)
					result.BurstHits++ // Track burst-specific rate limits
				} else if resp.StatusCode >= 200 && resp.StatusCode < 300 {
					result.Success++
					atomic.AddInt64(&progress.successCount, 1)
					successInBurst++
				} else {
					result.Errors++
					atomic.AddInt64(&progress.errorCount, 1)
				}
			}

			result.AvgLatencyMs = (result.AvgLatencyMs + latency.Milliseconds()) / 2

			// No delay in burst - test rapid-fire requests
		}

		// Brief pause between bursts to measure recovery
		if burst < 2 {
			time.Sleep(3 * time.Second)
		}
	}

summary:
	if result.RequestsSent > 0 {
		result.AvgLatencyMs = time.Since(start).Milliseconds() / int64(result.RequestsSent)
	}
	return result
}

// testPremiumStressHTTP performs premium stress testing with high-frequency HTTP requests
func testPremiumStressHTTP(ctx context.Context, account ServiceAccount, progress *ProgressTracker) TestResult {
	client := &http.Client{Timeout: 5 * time.Second}
	result := TestResult{
		APIKey:         account.AccessKey,
		Group:          account.Group,
		Method:         "Premium-Stress-HTTP",
		HeaderCaptures: make([]ResponseHeaders, 0),
		ErrorDetails:   make(map[string]int),
		ErrorExamples:  make([]ErrorExample, 0),
	}

	start := time.Now()

	// High-frequency requests - try to find the actual rate limit
	for i := 0; i < 200; i++ { // More requests to stress test
		select {
		case <-ctx.Done():
			goto stressSummary
		default:
		}

		reqStart := time.Now()
		object := fmt.Sprintf("stress-test-%s-%d.txt", account.AccessKey[:8], i)
		body := bytes.NewReader([]byte(fmt.Sprintf("stress test data %d", i)))

		req, err := http.NewRequestWithContext(ctx, "PUT",
			fmt.Sprintf("http://localhost/test-bucket/%s", object), body)
		if err != nil {
			result.Errors++
			atomic.AddInt64(&progress.errorCount, 1)
			errorType := categorizeError(err.Error(), 0)
			result.ErrorDetails[errorType]++
			continue
		}

		req.Header.Set("Authorization", fmt.Sprintf("AWS %s:testsignature", account.AccessKey))
		req.Header.Set("Content-Type", "text/plain")

		resp, err := client.Do(req)
		latency := time.Since(reqStart)

		result.RequestsSent++
		atomic.AddInt64(&progress.totalRequests, 1)

		if err != nil {
			result.Errors++
			atomic.AddInt64(&progress.errorCount, 1)
			errorType := categorizeError(err.Error(), 0)
			result.ErrorDetails[errorType]++
		} else {
			defer resp.Body.Close()

			// Capture headers for analysis
			headerCapture := ResponseHeaders{
				Timestamp:  time.Now(),
				StatusCode: resp.StatusCode,
				LatencyMs:  latency.Milliseconds(),
				Headers:    make(map[string]string),
			}

			for _, header := range []string{"X-Auth-Method", "X-Ratelimit-Group", "X-Ratelimit-Limit-Per-Second", "X-Ratelimit-Current-Per-Second"} {
				if value := resp.Header.Get(header); value != "" {
					headerCapture.Headers[header] = value
				}
			}

			result.HeaderCaptures = append(result.HeaderCaptures, headerCapture)

			if resp.StatusCode == 429 {
				result.RateLimited++
				atomic.AddInt64(&progress.rateLimitCount, 1)
			} else if resp.StatusCode >= 200 && resp.StatusCode < 300 {
				result.Success++
				atomic.AddInt64(&progress.successCount, 1)
			} else {
				result.Errors++
				atomic.AddInt64(&progress.errorCount, 1)
				errorType := categorizeError("", resp.StatusCode)
				result.ErrorDetails[errorType]++
			}
		}

		result.AvgLatencyMs = (result.AvgLatencyMs + latency.Milliseconds()) / 2

		// Very minimal delay to stress test
		time.Sleep(10 * time.Millisecond)
	}

stressSummary:
	if result.RequestsSent > 0 {
		result.AvgLatencyMs = time.Since(start).Milliseconds() / int64(result.RequestsSent)
	}
	return result
}

// testIntensiveBurst performs intensive burst testing for premium accounts
func testIntensiveBurst(ctx context.Context, account ServiceAccount, progress *ProgressTracker) TestResult {
	client := &http.Client{Timeout: 3 * time.Second}
	result := TestResult{
		APIKey:         account.AccessKey,
		Group:          account.Group,
		Method:         "Intensive-Burst",
		HeaderCaptures: make([]ResponseHeaders, 0),
		ErrorDetails:   make(map[string]int),
		ErrorExamples:  make([]ErrorExample, 0),
	}

	start := time.Now()

	// Multiple intensive bursts
	for burst := 0; burst < 5; burst++ {
		select {
		case <-ctx.Done():
			goto summary
		default:
		}

		// Send 50 rapid requests in each burst
		for i := 0; i < 50; i++ {
			reqStart := time.Now()
			object := fmt.Sprintf("burst-%s-%d-%d.txt", account.AccessKey[:8], burst, i)
			body := bytes.NewReader([]byte(fmt.Sprintf("burst %d-%d", burst, i)))

			req, err := http.NewRequestWithContext(ctx, "PUT",
				fmt.Sprintf("http://localhost/test-bucket/%s", object), body)
			if err != nil {
				result.Errors++
				errorType := categorizeError(err.Error(), 0)
				result.ErrorDetails[errorType]++
				continue
			}

			req.Header.Set("Authorization", fmt.Sprintf("AWS %s:testsignature", account.AccessKey))
			req.Header.Set("Content-Type", "text/plain")

			resp, err := client.Do(req)
			latency := time.Since(reqStart)

			result.RequestsSent++
			atomic.AddInt64(&progress.totalRequests, 1)

			if err != nil {
				result.Errors++
				atomic.AddInt64(&progress.errorCount, 1)
				errorType := categorizeError(err.Error(), 0)
				result.ErrorDetails[errorType]++
			} else {
				defer resp.Body.Close()
				if resp.StatusCode == 429 {
					result.RateLimited++
					atomic.AddInt64(&progress.rateLimitCount, 1)
				} else if resp.StatusCode >= 200 && resp.StatusCode < 300 {
					result.Success++
					atomic.AddInt64(&progress.successCount, 1)
				} else {
					result.Errors++
					atomic.AddInt64(&progress.errorCount, 1)
					errorType := categorizeError("", resp.StatusCode)
					result.ErrorDetails[errorType]++
				}
			}

			result.AvgLatencyMs = (result.AvgLatencyMs + latency.Milliseconds()) / 2
		}

		// Short pause between bursts
		if burst < 4 {
			time.Sleep(2 * time.Second)
		}
	}

summary:
	if result.RequestsSent > 0 {
		result.AvgLatencyMs = time.Since(start).Milliseconds() / int64(result.RequestsSent)
	}
	return result
}

// testSustainedLoad performs sustained load testing
func testSustainedLoad(ctx context.Context, account ServiceAccount, progress *ProgressTracker) TestResult {
	client := &http.Client{Timeout: 10 * time.Second}
	result := TestResult{
		APIKey:         account.AccessKey,
		Group:          account.Group,
		Method:         "Sustained-Load",
		HeaderCaptures: make([]ResponseHeaders, 0),
		ErrorDetails:   make(map[string]int),
		ErrorExamples:  make([]ErrorExample, 0),
	}

	start := time.Now()

	// Sustained requests until context timeout
	i := 0
	for {
		select {
		case <-ctx.Done():
			goto summary
		default:
		}

		reqStart := time.Now()
		object := fmt.Sprintf("sustained-%s-%d.txt", account.AccessKey[:8], i)
		body := bytes.NewReader([]byte(fmt.Sprintf("sustained %d", i)))

		req, err := http.NewRequestWithContext(ctx, "PUT",
			fmt.Sprintf("http://localhost/test-bucket/%s", object), body)
		if err != nil {
			result.Errors++
			errorType := categorizeError(err.Error(), 0)
			result.ErrorDetails[errorType]++
			i++
			continue
		}

		req.Header.Set("Authorization", fmt.Sprintf("AWS %s:testsignature", account.AccessKey))
		req.Header.Set("Content-Type", "text/plain")

		resp, err := client.Do(req)
		latency := time.Since(reqStart)

		result.RequestsSent++
		atomic.AddInt64(&progress.totalRequests, 1)

		if err != nil {
			result.Errors++
			atomic.AddInt64(&progress.errorCount, 1)
			errorType := categorizeError(err.Error(), 0)
			result.ErrorDetails[errorType]++
		} else {
			defer resp.Body.Close()
			if resp.StatusCode == 429 {
				result.RateLimited++
				atomic.AddInt64(&progress.rateLimitCount, 1)
			} else if resp.StatusCode >= 200 && resp.StatusCode < 300 {
				result.Success++
				atomic.AddInt64(&progress.successCount, 1)
			} else {
				result.Errors++
				atomic.AddInt64(&progress.errorCount, 1)
				errorType := categorizeError("", resp.StatusCode)
				result.ErrorDetails[errorType]++
			}
		}

		result.AvgLatencyMs = (result.AvgLatencyMs + latency.Milliseconds()) / 2

		// Consistent pacing
		time.Sleep(100 * time.Millisecond)
		i++
	}

summary:
	if result.RequestsSent > 0 {
		result.AvgLatencyMs = time.Since(start).Milliseconds() / int64(result.RequestsSent)
	}
	return result
}
