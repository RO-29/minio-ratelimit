# Snowball vs Concurrent Upload Comparison

This Go program compares the performance of two approaches for uploading 100 objects to MinIO:

1. **Concurrent Individual Uploads**: Upload each object separately using goroutines with controlled concurrency
2. **Snowball Multipart Upload**: Bundle all objects into a single compressed TAR archive and upload as one operation

## Features

- 🚀 Tests both upload strategies with identical data
- 📊 Comprehensive performance metrics (latency, throughput, success rates)
- 🎯 Real-time progress tracking
- 💡 Automated recommendations based on results
- 🔧 Premium tier configuration support
- 📈 Detailed comparison analysis

## Configuration

Update the constants in `main.go` to match your setup:

```go
const (
    endpoint        = "localhost:9000"      // Your MinIO endpoint
    accessKeyID     = "premium-access-key"   // Premium tier access key
    secretAccessKey = "premium-secret-key"   // Premium tier secret key
    useSSL          = false                 // Use HTTPS/SSL
    bucketName      = "snowball-test"       // Test bucket name
    objectCount     = 100                   // Number of objects to upload
    objectSize      = 1024 * 1024          // 1MB per object
    concurrency     = 10                    // Concurrent uploads limit
)
```

## Running the Test

1. **Install dependencies:**
   ```bash
   go mod tidy
   ```

2. **Make sure MinIO is running** and accessible at your configured endpoint

3. **Run the comparison:**
   ```bash
   go run main.go
   ```

## Test Scenarios

### Test 1: Concurrent Individual Uploads
- Uploads 100 objects individually using goroutines
- Limits concurrency to prevent overwhelming the server
- Measures per-object latency statistics
- Tracks success/failure rates

### Test 2: Snowball Multipart Upload
- Bundles all 100 objects into a single TAR archive
- Enables compression for optimal network utilization
- Uploads as a single multipart operation
- Objects are auto-extracted server-side

## Performance Metrics

The program measures and compares:

- **Duration**: Total time for each approach
- **Throughput**: Data transfer rate (MB/s)
- **Latency**: Average, minimum, and maximum response times
- **Success Rate**: Percentage of successful uploads
- **Error Handling**: Failed operations count

## Expected Results

**Snowball advantages:**
- ⚡ Better throughput for bulk operations
- 🔒 Atomic operations (all-or-nothing)
- 📦 Compression reduces network usage
- 🚀 Reduced API call overhead

**Concurrent advantages:**
- 🎯 Lower latency for individual objects
- 📊 Partial success handling
- 🔧 Better for mixed object sizes
- 💪 Resilient to individual failures

## Sample Output

```
🚀 SNOWBALL VS CONCURRENT UPLOAD COMPARISON
===============================================

Test Configuration:
  • Objects: 100
  • Object Size: 1 MB each
  • Total Data: 100 MB
  • Concurrency: 10 (for individual uploads)
  • Endpoint: localhost:9000

=== TEST 1: CONCURRENT INDIVIDUAL UPLOADS ===
Starting concurrent individual uploads...
  Progress: 10/100 objects uploaded (10.0%)
  Progress: 50/100 objects uploaded (50.0%)
  Progress: 100/100 objects uploaded (100.0%)

--- Concurrent Individual Uploads Results ---
  Duration:      8.45 seconds
  Success Rate:  100/100 (100.0%)
  Throughput:    11.83 MB/s
  Avg Latency:   847ms
  Min Latency:   623ms
  Max Latency:   1.2s

=== TEST 2: SNOWBALL MULTIPART UPLOAD ===
Starting snowball multipart upload...
  Progress: 10/100 objects prepared for snowball (10.0%)
  Progress: 100/100 objects prepared for snowball (100.0%)
  All 100 objects prepared for snowball upload
  ✓ Snowball upload completed successfully

--- Snowball Multipart Upload Results ---
  Duration:      3.21 seconds
  Success Rate:  100/100 (100.0%)
  Throughput:    31.15 MB/s
  Avg Latency:   32ms

=== PERFORMANCE COMPARISON ===
📊 Performance Comparison:

⚡ Snowball is 62.0% faster
   Snowball: 3.21s vs Concurrent: 8.45s

📈 Throughput Comparison:
   Concurrent: 11.83 MB/s
   Snowball:   31.15 MB/s
   Snowball has 163.3% higher throughput

✅ Success Rate Comparison:
   Concurrent: 100.0% (100/100)
   Snowball:   100.0% (100/100)

💡 Recommendations:
   • Snowball is recommended for bulk uploads of many small objects
   • Provides better resource utilization and atomic operations

🎉 Comparison Complete! 🎉
```

## Customization

You can modify the test parameters:

- **Object count**: Change `objectCount` for different batch sizes
- **Object size**: Adjust `objectSize` for different file sizes
- **Concurrency**: Modify `concurrency` for concurrent upload limits
- **Compression**: Toggle compression in snowball options
- **Memory usage**: Switch between in-memory and file-based snowball

## Requirements

- Go 1.21 or later
- MinIO server running and accessible
- Premium tier credentials configured
- Network connectivity to MinIO endpoint

## Troubleshooting

1. **Connection errors**: Verify MinIO endpoint and credentials
2. **Permission issues**: Ensure access keys have required permissions
3. **Memory issues**: Reduce object count or size for limited memory
4. **Network timeouts**: Check network connectivity and MinIO configuration