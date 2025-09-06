package main

// import (
// 	"bytes"
// 	"context"
// 	"crypto/rand"
// 	"fmt"
// 	"log"
// 	"sync"
// 	"sync/atomic"
// 	"time"

// 	"github.com/minio/minio-go/v7"
// 	"github.com/minio/minio-go/v7/pkg/credentials"
// )

// // Configuration - Premium tier keys
// const (
// 	endpoint        = "localhost"                                // Change to your MinIO endpoint
// 	accessKeyID     = "MM1CHUWPUPLEO4T8QLB4"                     // Premium tier access key
// 	secretAccessKey = "m2b+H0UaudrnmIl+OkrC3j4lgBQpihyrXh1T3fWy" // Premium tier secret key
// 	useSSL          = true
// 	bucketName      = "snowball-test"
// 	objectCount     = 1000
// 	objectSize      = 1024 * 1024 // 1MB per object (decent size)
// 	concurrency     = 50          // Number of concurrent uploads for individual test
// )

// // Colors for terminal output
// const (
// 	ColorReset  = "\033[0m"
// 	ColorRed    = "\033[31m"
// 	ColorGreen  = "\033[32m"
// 	ColorYellow = "\033[33m"
// 	ColorBlue   = "\033[34m"
// 	ColorPurple = "\033[35m"
// 	ColorCyan   = "\033[36m"
// )

// type TestResults struct {
// 	TestName     string
// 	Duration     time.Duration
// 	ObjectCount  int
// 	TotalSize    int64
// 	Throughput   float64 // MB/s
// 	AvgLatency   time.Duration
// 	MinLatency   time.Duration
// 	MaxLatency   time.Duration
// 	ErrorCount   int64
// 	SuccessCount int64
// }

// type SnowballDemo struct {
// 	client     *minio.Client
// 	bucketName string
// 	testData   []byte
// }

// func NewSnowballDemo() (*SnowballDemo, error) {
// 	// Initialize minio client with premium credentials
// 	minioClient, err := minio.New(endpoint, &minio.Options{
// 		Creds:  credentials.NewStaticV4(accessKeyID, secretAccessKey, ""),
// 		Secure: useSSL,
// 	})
// 	if err != nil {
// 		return nil, err
// 	}

// 	return &SnowballDemo{
// 		client:     minioClient,
// 		bucketName: bucketName,
// 		testData:   generateTestData(objectSize),
// 	}, nil
// }

// func main() {
// 	fmt.Printf("%s🚀 SNOWBALL VS CONCURRENT UPLOAD COMPARISON%s\n", ColorPurple, ColorReset)
// 	fmt.Printf("%s===============================================%s\n\n", ColorPurple, ColorReset)

// 	demo, err := NewSnowballDemo()
// 	if err != nil {
// 		log.Fatalf("Failed to initialize demo: %v", err)
// 	}

// 	ctx := context.Background()

// 	// Setup
// 	if err := demo.setupBucket(ctx); err != nil {
// 		log.Fatalf("Failed to setup bucket: %v", err)
// 	}

// 	// Test configuration summary
// 	fmt.Printf("%sTest Configuration:%s\n", ColorCyan, ColorReset)
// 	fmt.Printf("  • Objects: %d\n", objectCount)
// 	fmt.Printf("  • Object Size: %d MB each\n", objectSize/1024/1024)
// 	fmt.Printf("  • Total Data: %d MB\n", (objectCount*objectSize)/1024/1024)
// 	fmt.Printf("  • Concurrency: %d (for individual uploads)\n", concurrency)
// 	fmt.Printf("  • Endpoint: %s\n\n", endpoint)

// 	// Run tests
// 	var concurrentResults, snowballResults TestResults

// 	// Test 1: Concurrent Individual Uploads
// 	fmt.Printf("%s=== TEST 1: CONCURRENT INDIVIDUAL UPLOADS ===%s\n", ColorBlue, ColorReset)
// 	concurrentResults = demo.testConcurrentUploads(ctx)
// 	demo.printResults(concurrentResults)

// 	// Clean up between tests
// 	//demo.cleanupObjects(ctx, "concurrent")

// 	fmt.Printf("\n%s=== TEST 2: SNOWBALL MULTIPART UPLOAD ===%s\n", ColorBlue, ColorReset)
// 	snowballResults = demo.testSnowballUpload(ctx)
// 	demo.printResults(snowballResults)

// 	// Clean up after tests
// 	//demo.cleanupObjects(ctx, "snowball")

// 	// Compare results
// 	fmt.Printf("\n%s=== PERFORMANCE COMPARISON ===%s\n", ColorGreen, ColorReset)
// 	demo.compareResults(concurrentResults, snowballResults)

// 	fmt.Printf("\n%s🎉 Comparison Complete! 🎉%s\n", ColorGreen, ColorReset)
// }

// func (demo *SnowballDemo) testConcurrentUploads(ctx context.Context) TestResults {
// 	fmt.Printf("Starting concurrent individual uploads...\n")

// 	var wg sync.WaitGroup
// 	var errorCount, successCount int64
// 	var totalLatency int64
// 	var minLatency, maxLatency int64

// 	// Initialize min/max latency
// 	minLatency = int64(time.Hour)
// 	maxLatency = 0

// 	// Channel to limit concurrency
// 	semaphore := make(chan struct{}, concurrency)

// 	startTime := time.Now()

// 	// Progress tracking
// 	var completed int64
// 	go func() {
// 		for {
// 			select {
// 			case <-ctx.Done():
// 				return
// 			case <-time.After(1 * time.Second):
// 				current := atomic.LoadInt64(&completed)
// 				if current > 0 && current < objectCount {
// 					fmt.Printf("  Progress: %d/%d objects uploaded (%.1f%%)\n",
// 						current, objectCount, float64(current)/float64(objectCount)*100)
// 				}
// 			}
// 		}
// 	}()

// 	for i := 0; i < objectCount; i++ {
// 		wg.Add(1)
// 		go func(objIndex int) {
// 			defer wg.Done()

// 			// Acquire semaphore
// 			semaphore <- struct{}{}
// 			defer func() { <-semaphore }()

// 			objectName := fmt.Sprintf("concurrent/object-%d", objIndex)
// 			reader := bytes.NewReader(demo.testData)

// 			objStartTime := time.Now()
// 			_, err := demo.client.PutObject(ctx, demo.bucketName, objectName, reader,
// 				int64(len(demo.testData)), minio.PutObjectOptions{
// 					ContentType: "application/octet-stream",
// 				})
// 			latency := time.Since(objStartTime)

// 			if err != nil {
// 				atomic.AddInt64(&errorCount, 1)
// 			} else {
// 				atomic.AddInt64(&successCount, 1)
// 				atomic.AddInt64(&totalLatency, int64(latency))

// 				// Update min/max latency
// 				for {
// 					current := atomic.LoadInt64(&minLatency)
// 					if int64(latency) < current {
// 						if atomic.CompareAndSwapInt64(&minLatency, current, int64(latency)) {
// 							break
// 						}
// 					} else {
// 						break
// 					}
// 				}

// 				for {
// 					current := atomic.LoadInt64(&maxLatency)
// 					if int64(latency) > current {
// 						if atomic.CompareAndSwapInt64(&maxLatency, current, int64(latency)) {
// 							break
// 						}
// 					} else {
// 						break
// 					}
// 				}
// 			}

// 			atomic.AddInt64(&completed, 1)
// 		}(i)
// 	}

// 	wg.Wait()
// 	totalDuration := time.Since(startTime)

// 	avgLatency := time.Duration(0)
// 	if successCount > 0 {
// 		avgLatency = time.Duration(totalLatency / successCount)
// 	}

// 	totalSizeBytes := int64(objectCount * objectSize)
// 	throughputMBps := float64(totalSizeBytes) / float64(totalDuration.Seconds()) / (1024 * 1024)

// 	return TestResults{
// 		TestName:     "Concurrent Individual Uploads",
// 		Duration:     totalDuration,
// 		ObjectCount:  objectCount,
// 		TotalSize:    totalSizeBytes,
// 		Throughput:   throughputMBps,
// 		AvgLatency:   avgLatency,
// 		MinLatency:   time.Duration(minLatency),
// 		MaxLatency:   time.Duration(maxLatency),
// 		ErrorCount:   errorCount,
// 		SuccessCount: successCount,
// 	}
// }

// func (demo *SnowballDemo) testSnowballUpload(ctx context.Context) TestResults {
// 	fmt.Printf("Starting snowball multipart upload...\n")

// 	startTime := time.Now()

// 	// Create channel for snowball objects
// 	objChan := make(chan minio.SnowballObject, objectCount)

// 	// Start snowball upload in goroutine
// 	var uploadErr error
// 	uploadDone := make(chan struct{})

// 	go func() {
// 		defer close(uploadDone)
// 		opts := minio.SnowballOptions{
// 			Opts: minio.PutObjectOptions{
// 				ContentType: "application/octet-stream",
// 			},
// 			InMemory: true, // Use in-memory for better performance with smaller objects
// 			Compress: true, // Enable compression
// 		}
// 		uploadErr = demo.client.PutObjectsSnowball(ctx, demo.bucketName, opts, objChan)
// 	}()

// 	// Feed objects to the channel
// 	go func() {
// 		defer close(objChan)
// 		for i := 0; i < objectCount; i++ {
// 			select {
// 			case <-ctx.Done():
// 				return
// 			case objChan <- minio.SnowballObject{
// 				Key:     fmt.Sprintf("snowball/object-%d", i),
// 				Size:    int64(len(demo.testData)),
// 				ModTime: time.Now(),
// 				Content: bytes.NewReader(demo.testData),
// 			}:
// 				if i%10 == 0 {
// 					fmt.Printf("  Progress: %d/%d objects prepared for snowball (%.1f%%)\n",
// 						i+1, objectCount, float64(i+1)/float64(objectCount)*100)
// 				}
// 			}
// 		}
// 		fmt.Printf("  All %d objects prepared for snowball upload\n", objectCount)
// 	}()

// 	// Wait for upload to complete
// 	<-uploadDone
// 	totalDuration := time.Since(startTime)

// 	var errorCount, successCount int64
// 	if uploadErr != nil {
// 		errorCount = 1
// 		successCount = 0
// 		fmt.Printf("  %sSnowball upload error: %v%s\n", ColorRed, uploadErr, ColorReset)
// 	} else {
// 		errorCount = 0
// 		successCount = int64(objectCount)
// 		fmt.Printf("  %sSnowball upload completed successfully%s\n", ColorGreen, ColorReset)
// 	}

// 	totalSizeBytes := int64(objectCount * objectSize)
// 	throughputMBps := float64(totalSizeBytes) / float64(totalDuration.Seconds()) / (1024 * 1024)

// 	// For snowball, latency is the total time divided by object count
// 	avgLatency := totalDuration / time.Duration(objectCount)

// 	return TestResults{
// 		TestName:     "Snowball Multipart Upload",
// 		Duration:     totalDuration,
// 		ObjectCount:  objectCount,
// 		TotalSize:    totalSizeBytes,
// 		Throughput:   throughputMBps,
// 		AvgLatency:   avgLatency,
// 		MinLatency:   avgLatency, // All objects uploaded together
// 		MaxLatency:   avgLatency, // All objects uploaded together
// 		ErrorCount:   errorCount,
// 		SuccessCount: successCount,
// 	}
// }

// func (demo *SnowballDemo) printResults(results TestResults) {
// 	fmt.Printf("\n%s--- %s Results ---%s\n", ColorYellow, results.TestName, ColorReset)
// 	fmt.Printf("  Duration:      %.2f seconds\n", results.Duration.Seconds())
// 	fmt.Printf("  Success Rate:  %d/%d (%.1f%%)\n",
// 		results.SuccessCount, results.ObjectCount,
// 		float64(results.SuccessCount)/float64(results.ObjectCount)*100)
// 	fmt.Printf("  Throughput:    %.2f MB/s\n", results.Throughput)
// 	fmt.Printf("  Avg Latency:   %v\n", results.AvgLatency)
// 	if results.MinLatency != results.MaxLatency {
// 		fmt.Printf("  Min Latency:   %v\n", results.MinLatency)
// 		fmt.Printf("  Max Latency:   %v\n", results.MaxLatency)
// 	}
// 	if results.ErrorCount > 0 {
// 		fmt.Printf("  Errors:        %d\n", results.ErrorCount)
// 	}
// }

// func (demo *SnowballDemo) compareResults(concurrent, snowball TestResults) {
// 	fmt.Printf("📊 Performance Comparison:\n\n")

// 	// Duration comparison
// 	if concurrent.Duration < snowball.Duration {
// 		improvement := ((snowball.Duration.Seconds() - concurrent.Duration.Seconds()) / snowball.Duration.Seconds()) * 100
// 		fmt.Printf("%s⚡ Concurrent uploads are %.1f%% faster%s\n", ColorGreen, improvement, ColorReset)
// 		fmt.Printf("   Concurrent: %.2fs vs Snowball: %.2fs\n",
// 			concurrent.Duration.Seconds(), snowball.Duration.Seconds())
// 	} else {
// 		improvement := ((concurrent.Duration.Seconds() - snowball.Duration.Seconds()) / concurrent.Duration.Seconds()) * 100
// 		fmt.Printf("%s⚡ Snowball is %.1f%% faster%s\n", ColorGreen, improvement, ColorReset)
// 		fmt.Printf("   Snowball: %.2fs vs Concurrent: %.2fs\n",
// 			snowball.Duration.Seconds(), concurrent.Duration.Seconds())
// 	}

// 	// Throughput comparison
// 	fmt.Printf("\n📈 Throughput Comparison:\n")
// 	fmt.Printf("   Concurrent: %.2f MB/s\n", concurrent.Throughput)
// 	fmt.Printf("   Snowball:   %.2f MB/s\n", snowball.Throughput)

// 	if concurrent.Throughput > snowball.Throughput {
// 		improvement := ((concurrent.Throughput - snowball.Throughput) / snowball.Throughput) * 100
// 		fmt.Printf("   %sConcurrent has %.1f%% higher throughput%s\n", ColorGreen, improvement, ColorReset)
// 	} else {
// 		improvement := ((snowball.Throughput - concurrent.Throughput) / concurrent.Throughput) * 100
// 		fmt.Printf("   %sSnowball has %.1f%% higher throughput%s\n", ColorGreen, improvement, ColorReset)
// 	}

// 	// Success rate comparison
// 	concurrentSuccessRate := float64(concurrent.SuccessCount) / float64(concurrent.ObjectCount) * 100
// 	snowballSuccessRate := float64(snowball.SuccessCount) / float64(snowball.ObjectCount) * 100

// 	fmt.Printf("\n✅ Success Rate Comparison:\n")
// 	fmt.Printf("   Concurrent: %.1f%% (%d/%d)\n",
// 		concurrentSuccessRate, concurrent.SuccessCount, concurrent.ObjectCount)
// 	fmt.Printf("   Snowball:   %.1f%% (%d/%d)\n",
// 		snowballSuccessRate, snowball.SuccessCount, snowball.ObjectCount)

// 	// Recommendations
// 	fmt.Printf("\n💡 Recommendations:\n")
// 	if snowball.Duration < concurrent.Duration && snowball.ErrorCount == 0 {
// 		fmt.Printf("   %s• Snowball is recommended for bulk uploads of many small objects%s\n", ColorGreen, ColorReset)
// 		fmt.Printf("   %s• Provides better resource utilization and atomic operations%s\n", ColorCyan, ColorReset)
// 	} else if concurrent.Duration < snowball.Duration {
// 		fmt.Printf("   %s• Concurrent uploads may be better for this specific scenario%s\n", ColorGreen, ColorReset)
// 		fmt.Printf("   %s• Consider snowball for larger batches or when atomicity is needed%s\n", ColorCyan, ColorReset)
// 	}

// 	if concurrent.ErrorCount > 0 && snowball.ErrorCount == 0 {
// 		fmt.Printf("   %s• Snowball provides better reliability (no partial failures)%s\n", ColorGreen, ColorReset)
// 	}
// }

// func (demo *SnowballDemo) setupBucket(ctx context.Context) error {
// 	exists, err := demo.client.BucketExists(ctx, demo.bucketName)
// 	if err != nil {
// 		return err
// 	}

// 	if !exists {
// 		err = demo.client.MakeBucket(ctx, demo.bucketName, minio.MakeBucketOptions{})
// 		if err != nil {
// 			return err
// 		}
// 		fmt.Printf("%s✓ Created bucket: %s%s\n", ColorGreen, demo.bucketName, ColorReset)
// 	} else {
// 		fmt.Printf("%s• Using existing bucket: %s%s\n", ColorCyan, demo.bucketName, ColorReset)
// 	}

// 	return nil
// }

// func (demo *SnowballDemo) cleanupObjects(ctx context.Context, prefix string) {
// 	fmt.Printf("Cleaning up %s test objects...\n", prefix)

// 	objectsCh := demo.client.ListObjects(ctx, demo.bucketName, minio.ListObjectsOptions{
// 		Prefix:    prefix + "/",
// 		Recursive: true,
// 	})

// 	for object := range objectsCh {
// 		if object.Err != nil {
// 			fmt.Printf("Error listing object: %v\n", object.Err)
// 			continue
// 		}

// 		err := demo.client.RemoveObject(ctx, demo.bucketName, object.Key, minio.RemoveObjectOptions{})
// 		if err != nil {
// 			fmt.Printf("Error removing object %s: %v\n", object.Key, err)
// 		}
// 	}
// }

// // generateTestData creates random test data of specified size
// func generateTestData(size int) []byte {
// 	data := make([]byte, size)
// 	_, err := rand.Read(data)
// 	if err != nil {
// 		// Fallback to pattern-based data if random fails
// 		pattern := []byte("MinIO Snowball vs Concurrent Upload Test Data - ")
// 		for i := 0; i < size; i += len(pattern) {
// 			copy(data[i:], pattern)
// 		}
// 	}
// 	return data
// }
