package main

import (
	"bytes"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"time"
)

func main() {
	fmt.Println("🌐 Bandwidth Limiting Test Script")
	fmt.Println("=================================")

	// Test with a premium API key
	apiKey := "1UPPILE429UEXN0017XJ"
	
	// Create test data (1MB)
	testData := make([]byte, 1024*1024)
	for i := range testData {
		testData[i] = byte(i % 256)
	}

	client := &http.Client{Timeout: 30 * time.Second}
	objectKey := fmt.Sprintf("bandwidth-test-%d", time.Now().Unix())

	fmt.Printf("🧪 Testing with API key: %s\n", apiKey)
	fmt.Printf("📦 Upload size: %d bytes (1MB)\n\n", len(testData))

	// Test Upload
	fmt.Println("📤 Testing Upload Speed...")
	uploadStart := time.Now()
	
	req, err := http.NewRequest("PUT", 
		fmt.Sprintf("http://localhost/test-bucket/%s", objectKey), 
		bytes.NewReader(testData))
	if err != nil {
		fmt.Printf("❌ Error creating upload request: %v\n", err)
		return
	}

	req.Header.Set("Authorization", fmt.Sprintf("AWS %s:testsignature", apiKey))
	req.Header.Set("Content-Type", "application/octet-stream")

	resp, err := client.Do(req)
	uploadDuration := time.Since(uploadStart)
	
	if err != nil {
		fmt.Printf("❌ Upload error: %v\n", err)
		return
	}
	defer resp.Body.Close()

	uploadSpeed := int64(float64(len(testData)) / uploadDuration.Seconds())
	
	fmt.Printf("✅ Upload completed in %v\n", uploadDuration)
	fmt.Printf("⚡ Upload speed: %s\n", formatBytesPerSec(uploadSpeed))
	fmt.Printf("📊 Response status: %d\n", resp.StatusCode)
	
	// Show bandwidth headers
	fmt.Println("\n📋 Response Headers:")
	for _, header := range []string{"X-Bandwidth-Limit-Download", "X-Bandwidth-Limit-Upload", "X-Ratelimit-Group"} {
		if value := resp.Header.Get(header); value != "" {
			if header == "X-Bandwidth-Limit-Download" || header == "X-Bandwidth-Limit-Upload" {
				if bytes, err := strconv.ParseInt(value, 10, 64); err == nil {
					fmt.Printf("  %s: %s\n", header, formatBytesPerSec(bytes))
				} else {
					fmt.Printf("  %s: %s\n", header, value)
				}
			} else {
				fmt.Printf("  %s: %s\n", header, value)
			}
		}
	}

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		fmt.Println("\n📥 Testing Download Speed...")
		downloadStart := time.Now()
		
		req, err := http.NewRequest("GET", 
			fmt.Sprintf("http://localhost/test-bucket/%s", objectKey), nil)
		if err != nil {
			fmt.Printf("❌ Error creating download request: %v\n", err)
			return
		}

		req.Header.Set("Authorization", fmt.Sprintf("AWS %s:testsignature", apiKey))

		resp, err := client.Do(req)
		if err != nil {
			fmt.Printf("❌ Download error: %v\n", err)
			return
		}
		defer resp.Body.Close()
		
		// Read all data to measure actual download time
		downloadedData, err := io.ReadAll(resp.Body)
		downloadDuration := time.Since(downloadStart)
		
		if err != nil {
			fmt.Printf("❌ Error reading download: %v\n", err)
			return
		}

		downloadSpeed := int64(float64(len(downloadedData)) / downloadDuration.Seconds())
		
		fmt.Printf("✅ Download completed in %v\n", downloadDuration)
		fmt.Printf("⚡ Download speed: %s\n", formatBytesPerSec(downloadSpeed))
		fmt.Printf("📊 Downloaded %d bytes\n", len(downloadedData))

		// Show bandwidth efficiency
		if uploadLimitStr := resp.Header.Get("X-Bandwidth-Limit-Upload"); uploadLimitStr != "" {
			if uploadLimit, err := strconv.ParseInt(uploadLimitStr, 10, 64); err == nil {
				uploadEfficiency := float64(uploadSpeed) * 100.0 / float64(uploadLimit)
				fmt.Printf("\n📈 Upload Efficiency: %.1f%% of configured limit\n", uploadEfficiency)
			}
		}
		
		if downloadLimitStr := resp.Header.Get("X-Bandwidth-Limit-Download"); downloadLimitStr != "" {
			if downloadLimit, err := strconv.ParseInt(downloadLimitStr, 10, 64); err == nil {
				downloadEfficiency := float64(downloadSpeed) * 100.0 / float64(downloadLimit)
				fmt.Printf("📈 Download Efficiency: %.1f%% of configured limit\n", downloadEfficiency)
			}
		}
	} else {
		fmt.Printf("❌ Upload failed with status: %d\n", resp.StatusCode)
	}

	fmt.Println("\n🎯 Bandwidth limiting test completed!")
}

func formatBytesPerSec(bytesPerSec int64) string {
	if bytesPerSec >= 1073741824 {
		return fmt.Sprintf("%.1f GB/s", float64(bytesPerSec)/1073741824)
	} else if bytesPerSec >= 1048576 {
		return fmt.Sprintf("%.1f MB/s", float64(bytesPerSec)/1048576)
	} else if bytesPerSec >= 1024 {
		return fmt.Sprintf("%.1f KB/s", float64(bytesPerSec)/1024)
	} else if bytesPerSec > 0 {
		return fmt.Sprintf("%d bytes/s", bytesPerSec)
	} else {
		return "0 bytes/s"
	}
}