package main

import (
	"fmt"
	"net/http"
)

func main() {
	fmt.Printf("🔍 DEBUG: Testing HAProxy Debug Headers\n")
	fmt.Printf("=====================================\n\n")

	// Create a simple HTTP request with V2 authorization
	client := &http.Client{}
	req, _ := http.NewRequest("GET", "http://127.0.0.1/test-bucket/", nil)
	
	// Add V2 style authorization header
	req.Header.Set("Authorization", "AWS TESTKEY123456789:signature=")
	req.Header.Set("User-Agent", "Test-Client/1.0")
	
	fmt.Printf("🔑 TESTING V2 AUTH HEADER: %s\n", req.Header.Get("Authorization"))
	
	resp, err := client.Do(req)
	if err != nil {
		fmt.Printf("❌ Error: %v\n", err)
		return
	}
	defer resp.Body.Close()
	
	fmt.Printf("\n📥 HAProxy DEBUG HEADERS:\n")
	debugHeaders := []string{
		"X-Debug-Full-Auth",
		"X-Debug-Word1-Equals", 
		"X-Debug-Word2-Equals",
		"X-Debug-Word3-Equals",
		"X-Debug-Final-Key",
		"X-Debug-Auth-Method",
		"X-Debug-Rate-Group",
	}

	for _, header := range debugHeaders {
		value := resp.Header.Get(header)
		fmt.Printf("  %s: %s\n", header, value)
	}
	
	fmt.Printf("\nStatus: %s\n", resp.Status)
}