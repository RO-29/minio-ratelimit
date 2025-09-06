package main

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"log"
	"strings"
	"sync"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

// Configuration
const (
	endpoint        = "localhost"
	accessKeyID     = "minioadmin"
	secretAccessKey = "minioadmin"
	useSSL          = false
	bucketName      = "test-bucket"
	objectName      = "large-file.txt"
	partSize        = 5 * 1024 * 1024    // 5MB parts (minimum for S3/MinIO)
	totalSize       = 1024 * 1024 * 1024 // 1GB total file size (for demonstration purposes)
)

// Colors for terminal output
const (
	ColorReset  = "\033[0m"
	ColorRed    = "\033[31m"
	ColorGreen  = "\033[32m"
	ColorYellow = "\033[33m"
	ColorBlue   = "\033[34m"
	ColorPurple = "\033[35m"
	ColorCyan   = "\033[36m"
	ColorWhite  = "\033[37m"
)

type MultipartUploadDemo struct {
	client     *minio.Client
	bucketName string
}

// Custom reader that tracks progress and simulates multipart behavior
type ProgressReader struct {
	reader      io.Reader
	totalSize   int64
	readSize    int64
	partSize    int64
	currentPart int
	totalParts  int
	mutex       sync.Mutex
	onProgress  func(part int, totalParts int, bytesRead int64, totalSize int64)
}

func NewMultipartUploadDemo() (*MultipartUploadDemo, error) {
	// Initialize minio client
	minioClient, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKeyID, secretAccessKey, ""),
		Secure: useSSL,
	})
	if err != nil {
		return nil, err
	}

	return &MultipartUploadDemo{
		client:     minioClient,
		bucketName: bucketName,
	}, nil
}

func main() {
	demo, err := NewMultipartUploadDemo()
	if err != nil {
		log.Fatalf("Failed to initialize demo: %v", err)
	}

	ctx := context.Background()

	fmt.Printf("%s🎬 MinIO Multipart Upload Complete Demonstration 🎬%s\n", ColorPurple, ColorReset)
	fmt.Printf("%sNote: This demo shows both conceptual multipart flow and actual MinIO client behavior%s\n\n", ColorCyan, ColorReset)

	// Setup
	if err := setupBucket(ctx, demo.client); err != nil {
		log.Fatalf("Failed to setup bucket: %v", err)
	}

	// Actual upload demonstration
	if err := demo.demonstrateActualUpload(ctx); err != nil {
		log.Printf("Actual upload demo failed: %v", err)
	}

	// Show advantages
	demo.demonstrateAdvantages()

	// Cleanup
	demo.cleanup(ctx)

	fmt.Printf("\n%s🎉 MinIO Multipart Upload Demonstration Complete! 🎉%s\n", ColorGreen, ColorReset)
	fmt.Printf("%s💡 Key Takeaway: MinIO Go client handles multipart uploads automatically,\n   but understanding the underlying process helps optimize your applications!%s\n", ColorCyan, ColorReset)
}

func setupBucket(ctx context.Context, client *minio.Client) error {
	exists, err := client.BucketExists(ctx, bucketName)
	if err != nil {
		return err
	}

	if !exists {
		err = client.MakeBucket(ctx, bucketName, minio.MakeBucketOptions{})
		if err != nil {
			return err
		}
		fmt.Printf("%s✓ Created bucket: %s%s\n", ColorGreen, bucketName, ColorReset)
	} else {
		fmt.Printf("%s• Using existing bucket: %s%s\n", ColorCyan, bucketName, ColorReset)
	}

	return nil
}

// Demonstrate actual MinIO upload with progress tracking
func (demo *MultipartUploadDemo) demonstrateActualUpload(ctx context.Context) error {
	demo.printHeader("Actual MinIO Upload with Progress Tracking")

	sampleData := generateSampleData(int(totalSize))

	demo.printInfo(fmt.Sprintf("Uploading %d bytes (%d MB)", totalSize, totalSize/1024/1024))
	demo.printInfo("MinIO will automatically use multipart upload for files > 64MB")
	demo.printInfo("For demonstration, we'll track progress manually")

	// Create progress tracking reader
	reader := bytes.NewReader(sampleData)
	progressReader := NewProgressReader(reader, totalSize, int64(partSize), func(part, totalParts int, bytesRead, totalSize int64) {
		progress := float64(bytesRead) / float64(totalSize) * 100
		progressBar := strings.Repeat("█", int(progress/5)) + strings.Repeat("░", 20-int(progress/5))
		fmt.Printf("  Simulated Part %d/%d: [%s] %.1f%% (%d/%d bytes)\n",
			part, totalParts, progressBar, progress, bytesRead, totalSize)
	})

	demo.printStep("1", "Starting Upload")
	startTime := time.Now()

	// Upload with progress tracking
	uploadInfo, err := demo.client.PutObject(ctx, demo.bucketName, objectName, progressReader, totalSize, minio.PutObjectOptions{
		ContentType: "text/plain",
		PartSize:    partSize,
	})
	if err != nil {
		return fmt.Errorf("upload failed: %v", err)
	}

	duration := time.Since(startTime)

	demo.printSuccess("Upload completed successfully!")
	demo.printSuccess(fmt.Sprintf("Uploaded: %d bytes in %v", uploadInfo.Size, duration))
	demo.printSuccess(fmt.Sprintf("ETag: %s", uploadInfo.ETag))
	demo.printSuccess(fmt.Sprintf("VersionID: %s", uploadInfo.VersionID))

	// Verify the upload
	demo.printStep("2", "Verifying Upload")
	objInfo, err := demo.client.StatObject(ctx, demo.bucketName, objectName, minio.StatObjectOptions{})
	if err != nil {
		return fmt.Errorf("verification failed: %v", err)
	}

	demo.printSuccess("Verification successful:")
	demo.printInfo(fmt.Sprintf("  Object: %s", objInfo.Key))
	demo.printInfo(fmt.Sprintf("  Size: %d bytes", objInfo.Size))
	demo.printInfo(fmt.Sprintf("  ETag: %s", objInfo.ETag))
	demo.printInfo(fmt.Sprintf("  Last Modified: %s", objInfo.LastModified))
	demo.printInfo(fmt.Sprintf("  Content-Type: %s", objInfo.ContentType))

	return nil
}

// Show multipart upload advantages
func (demo *MultipartUploadDemo) demonstrateAdvantages() {
	demo.printHeader("Multipart Upload Advantages")

	demo.printInfo("🚀 Improved Throughput:")
	demo.printInfo("   • Multiple parts can be uploaded in parallel")
	demo.printInfo("   • Better utilization of network bandwidth")
	demo.printInfo("   • Faster uploads for large files")

	demo.printInfo("🔄 Enhanced Reliability:")
	demo.printInfo("   • If a part fails, only that part needs to be retried")
	demo.printInfo("   • No need to restart the entire upload")
	demo.printInfo("   • Better handling of network interruptions")

	demo.printInfo("⚡ Flexibility:")
	demo.printInfo("   • Uploads can be paused and resumed")
	demo.printInfo("   • Support for very large files (up to 5TB)")
	demo.printInfo("   • Efficient memory usage")

	demo.printInfo("🔒 Integrity:")
	demo.printInfo("   • Each part has its own ETag for verification")
	demo.printInfo("   • Final object ETag combines all part ETags")
	demo.printInfo("   • Automatic corruption detection")
}

func (demo *MultipartUploadDemo) printHeader(title string) {
	fmt.Printf("\n%s=== %s ===%s\n", ColorBlue, title, ColorReset)
}

func (demo *MultipartUploadDemo) printStep(step, description string) {
	fmt.Printf("%s[STEP %s]%s %s\n", ColorYellow, step, ColorReset, description)
}

func (demo *MultipartUploadDemo) printSuccess(message string) {
	fmt.Printf("%s✓ %s%s\n", ColorGreen, message, ColorReset)
}

func (demo *MultipartUploadDemo) printError(message string) {
	fmt.Printf("%s✗ %s%s\n", ColorRed, message, ColorReset)
}

func (demo *MultipartUploadDemo) printInfo(message string) {
	fmt.Printf("%s• %s%s\n", ColorCyan, message, ColorReset)
}

func (demo *MultipartUploadDemo) printWarning(message string) {
	fmt.Printf("%s⚠ %s%s\n", ColorYellow, message, ColorReset)
}

// Generate sample data to upload
func generateSampleData(size int) []byte {
	data := make([]byte, size)
	pattern := []byte("This is sample data for MinIO multipart upload demonstration. ")

	for i := 0; i < size; i += len(pattern) {
		copy(data[i:], pattern)
	}
	return data[:size]
}

func (demo *MultipartUploadDemo) cleanup(ctx context.Context) {
	demo.printHeader("Cleanup")

	// Remove test objects
	objects := []string{objectName, "large-" + objectName}

	for _, obj := range objects {
		err := demo.client.RemoveObject(ctx, demo.bucketName, obj, minio.RemoveObjectOptions{})
		if err != nil {
			demo.printError(fmt.Sprintf("Failed to remove %s: %v", obj, err))
		} else {
			demo.printSuccess(fmt.Sprintf("Removed: %s", obj))
		}
	}
}

func NewProgressReader(reader io.Reader, size int64, partSize int64, onProgress func(int, int, int64, int64)) *ProgressReader {
	totalParts := int((size + partSize - 1) / partSize)
	return &ProgressReader{
		reader:      reader,
		totalSize:   size,
		partSize:    partSize,
		totalParts:  totalParts,
		currentPart: 1,
		onProgress:  onProgress,
	}
}

func (pr *ProgressReader) Read(p []byte) (n int, err error) {
	n, err = pr.reader.Read(p)

	pr.mutex.Lock()
	pr.readSize += int64(n)

	// Calculate current part based on bytes read
	newPart := int((pr.readSize-1)/pr.partSize) + 1
	if newPart > pr.currentPart && pr.onProgress != nil {
		pr.currentPart = newPart
		if pr.currentPart <= pr.totalParts {
			pr.onProgress(pr.currentPart, pr.totalParts, pr.readSize, pr.totalSize)
		}
	}
	pr.mutex.Unlock()

	return n, err
}
