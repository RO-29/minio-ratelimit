package main

import (
	"compress/gzip"
	"context"
	"fmt"
	"io"
	"log"
	"os"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

const (
	endpoint        = "localhost"
	accessKeyID     = "minioadmin"
	secretAccessKey = "minioadmin"
	useSSL          = true
	maxObjects      = 100
)

type ObjectProcessor struct {
	client            *minio.Client
	sourceBucket      string
	sourcePath        string
	destinationBucket string
}

func NewObjectProcessor(sourceBucket, sourcePath, destinationBucket string) (*ObjectProcessor, error) {
	client, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKeyID, secretAccessKey, ""),
		Secure: useSSL,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create MinIO client: %v", err)
	}

	return &ObjectProcessor{
		client:            client,
		sourceBucket:      sourceBucket,
		sourcePath:        sourcePath,
		destinationBucket: destinationBucket,
	}, nil
}

func (op *ObjectProcessor) ProcessObjects(ctx context.Context) error {
	objectCh := op.client.ListObjects(ctx, op.sourceBucket, minio.ListObjectsOptions{
		Prefix:    op.sourcePath,
		Recursive: true,
	})

	count := 0
	for objInfo := range objectCh {
		if objInfo.Err != nil {
			log.Printf("Error listing objects: %v", objInfo.Err)
			continue
		}

		if count >= maxObjects {
			fmt.Printf("Reached maximum object limit of %d\n", maxObjects)
			break
		}

		fmt.Printf("Processing object %d: %s (size: %d bytes)\n", count+1, objInfo.Key, objInfo.Size)

		if err := op.processObject(ctx, objInfo.Key); err != nil {
			log.Printf("Error processing object %s: %v", objInfo.Key, err)
			continue
		}

		count++
		fmt.Printf("Successfully processed and uploaded object: %s\n", objInfo.Key)
	}

	fmt.Printf("Total objects processed: %d\n", count)
	return nil
}

func (op *ObjectProcessor) processObject(ctx context.Context, objectKey string) error {
	object, err := op.client.GetObject(ctx, op.sourceBucket, objectKey, minio.GetObjectOptions{})
	if err != nil {
		return fmt.Errorf("failed to get object %s: %v", objectKey, err)
	}
	defer object.Close()

	pr, pw := io.Pipe()

	go func() {
		defer pw.Close()

		gzipWriter := gzip.NewWriter(pw)
		defer gzipWriter.Close()

		if _, err := io.Copy(gzipWriter, object); err != nil {
			log.Printf("Error compressing object %s: %v", objectKey, err)
			return
		}

		if err := gzipWriter.Flush(); err != nil {
			log.Printf("Error flushing gzip writer for %s: %v", objectKey, err)
		}
	}()

	compressedObjectKey := objectKey + ".gz"

	uploadInfo, err := op.client.PutObject(ctx, op.destinationBucket, compressedObjectKey, pr, -1, minio.PutObjectOptions{
		ContentType:     "application/gzip",
		ContentEncoding: "gzip",
	})
	if err != nil {
		return fmt.Errorf("failed to upload compressed object %s: %v", compressedObjectKey, err)
	}

	fmt.Printf("  Uploaded compressed object: %s (compressed size: %d bytes)\n",
		compressedObjectKey, uploadInfo.Size)

	return nil
}

func (op *ObjectProcessor) ensureBuckets(ctx context.Context) error {
	buckets := []string{op.sourceBucket, op.destinationBucket}

	for _, bucket := range buckets {
		exists, err := op.client.BucketExists(ctx, bucket)
		if err != nil {
			return fmt.Errorf("failed to check bucket %s: %v", bucket, err)
		}

		if !exists {
			if err := op.client.MakeBucket(ctx, bucket, minio.MakeBucketOptions{}); err != nil {
				return fmt.Errorf("failed to create bucket %s: %v", bucket, err)
			}
			fmt.Printf("Created bucket: %s\n", bucket)
		} else {
			fmt.Printf("Using existing bucket: %s\n", bucket)
		}
	}

	return nil
}

func main() {
	if len(os.Args) < 4 {
		fmt.Println("Usage: go run main.go <source-bucket> <source-path> <destination-bucket>")
		fmt.Println("Example: go run main.go source-bucket data/ dest-bucket")
		os.Exit(1)
	}

	sourceBucket := os.Args[1]
	sourcePath := os.Args[2]
	destinationBucket := os.Args[3]

	processor, err := NewObjectProcessor(sourceBucket, sourcePath, destinationBucket)
	if err != nil {
		log.Fatalf("Failed to create object processor: %v", err)
	}

	ctx := context.Background()

	fmt.Printf("Starting object processing...\n")
	fmt.Printf("Source: %s/%s\n", sourceBucket, sourcePath)
	fmt.Printf("Destination: %s\n", destinationBucket)
	fmt.Printf("Max objects: %d\n", maxObjects)

	if err := processor.ensureBuckets(ctx); err != nil {
		log.Fatalf("Failed to ensure buckets exist: %v", err)
	}

	startTime := time.Now()
	if err := processor.ProcessObjects(ctx); err != nil {
		log.Fatalf("Failed to process objects: %v", err)
	}

	fmt.Printf("Processing completed in %v\n", time.Since(startTime))
}
