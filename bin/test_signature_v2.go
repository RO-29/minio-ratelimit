package main

import (
	"fmt"
	"net/http"
	"strings"
	"time"
)

func main() {
	fmt.Printf("🔑 Premium API Key Rate Limiting Demo\n")
	fmt.Printf("=====================================\n\n")

	// Use real premium key: 5HQZO7EDOM4XBNO642GQ
	premiumKey := "5HQZO7EDOM4XBNO642GQ"
	
	// Test 1: Working request with AWS Signature V2 (simple to parse)
	fmt.Printf("1️⃣ SUCCESSFUL REQUEST - AWS Signature V2\n")
	fmt.Printf("=" + strings.Repeat("=", 50) + "\n")
	
	client := &http.Client{Timeout: 10 * time.Second}
	
	// Create request with AWS Signature V2 format (much easier for HAProxy to parse)
	req, _ := http.NewRequest("PUT", "http://localhost/test-bucket/premium-demo.txt", 
		strings.NewReader("Premium tier test content"))
	
	// Add AWS Signature V2 headers (simpler format)
	req.Header.Set("Authorization", fmt.Sprintf("AWS %s:demoSignatureV2", premiumKey))
	req.Header.Set("Content-Type", "text/plain")
	req.Header.Set("Date", time.Now().UTC().Format(http.TimeFormat))
	
	fmt.Printf("📤 REQUEST:\n")
	fmt.Printf("PUT %s\n", req.URL.String())
	for name, values := range req.Header {
		for _, value := range values {
			fmt.Printf("%s: %s\n", name, value)
		}
	}
	
	// Execute request
	resp, err := client.Do(req)
	if err != nil {
		fmt.Printf("❌ Error: %v\n", err)
		return
	}
	defer resp.Body.Close()
	
	fmt.Printf("\n📥 RESPONSE:\n")
	fmt.Printf("Status: %s\n", resp.Status)
	
	// Show rate limiting headers
	fmt.Printf("\n🎯 RATE LIMITING HEADERS:\n")
	headers := []string{
		"X-RateLimit-Group",
		"X-RateLimit-Limit-Per-Minute", 
		"X-RateLimit-Current-Per-Minute",
		"X-RateLimit-Limit-Per-Second",
		"X-RateLimit-Current-Per-Second",
		"X-API-Key",
		"X-Auth-Method",
	}
	
	for _, header := range headers {
		if value := resp.Header.Get(header); value != "" {
			fmt.Printf("  %s: %s\n", header, value)
		}
	}
	
	fmt.Printf("\n" + strings.Repeat("=", 60) + "\n")
	
	if resp.Header.Get("X-RateLimit-Group") == "premium" {
		fmt.Printf("✅ SUCCESS: Premium key recognized!\n")
		fmt.Printf("✅ Rate limit: %s requests/minute\n", resp.Header.Get("X-RateLimit-Limit-Per-Minute"))
		fmt.Printf("✅ Current usage: %s requests\n", resp.Header.Get("X-RateLimit-Current-Per-Minute"))
	} else {
		fmt.Printf("❌ Issue: Key not recognized as premium\n")
		fmt.Printf("   Group detected: %s\n", resp.Header.Get("X-RateLimit-Group"))
		fmt.Printf("   API Key parsed: %s\n", resp.Header.Get("X-API-Key"))
	}
}
