package main

import (
	"fmt"
	"regexp"
	"strings"
)

func main() {
	fmt.Printf("🔍 AWS SIGNATURE V4 HEADER ANALYSIS\n")
	fmt.Printf("===================================\n\n")

	// Real AWS V4 header from our test
	header := "AWS4-HMAC-SHA256 Credential=5HQZO7EDOM4XBNO642GQ/20250903/us-east-1/s3/aws4_request, SignedHeaders=content-length;content-md5;host;x-amz-content-sha256;x-amz-date, Signature=013a78546b675edddd2a3573ec028d8640bd3194a253779c86ecf5486350153b"
	
	fmt.Printf("📤 ORIGINAL HEADER:\n%s\n\n", header)
	
	// Method 1: Split by equals and analyze
	fmt.Printf("🔍 METHOD 1: Split by '=' character\n")
	parts := strings.Split(header, "=")
	for i, part := range parts {
		fmt.Printf("Part %d: %s\n", i, part)
	}
	fmt.Printf("\nword(2,'=') would get: %s\n", parts[1])
	fmt.Printf("word(1,'/') from that: %s\n\n", strings.Split(parts[1], "/")[0])
	
	// Method 2: Find "Credential=" specifically
	fmt.Printf("🔍 METHOD 2: Find 'Credential=' substring\n")
	credIndex := strings.Index(header, "Credential=")
	if credIndex != -1 {
		afterCred := header[credIndex+len("Credential="):]
		fmt.Printf("After 'Credential=': %s\n", afterCred)
		
		// Find first comma or slash
		commaIndex := strings.Index(afterCred, ",")
		slashIndex := strings.Index(afterCred, "/")
		
		if slashIndex != -1 && (slashIndex < commaIndex || commaIndex == -1) {
			apiKey := afterCred[:slashIndex]
			fmt.Printf("API Key (before '/'): %s\n", apiKey)
		}
	}
	
	// Method 3: Regex approach  
	fmt.Printf("\n🔍 METHOD 3: Regex extraction\n")
	regex := regexp.MustCompile(`Credential=([A-Z0-9]+)`)
	matches := regex.FindStringSubmatch(header)
	if len(matches) > 1 {
		fmt.Printf("Regex match: %s\n", matches[1])
	}
	
	// Method 4: More sophisticated regex
	fmt.Printf("\n🔍 METHOD 4: Advanced regex\n")
	regex2 := regexp.MustCompile(`Credential=([^/,\s]+)`)
	matches2 := regex2.FindStringSubmatch(header)
	if len(matches2) > 1 {
		fmt.Printf("Advanced regex match: %s\n", matches2[1])
	}
	
	// Method 5: Field-based extraction
	fmt.Printf("\n🔍 METHOD 5: Parse as structured data\n")
	parts5 := strings.Split(header, " ")
	for _, part := range parts5 {
		if strings.HasPrefix(part, "Credential=") {
			credPart := strings.TrimPrefix(part, "Credential=")
			credPart = strings.Split(credPart, ",")[0] // Remove everything after comma
			apiKey := strings.Split(credPart, "/")[0]  // Remove everything after slash
			fmt.Printf("Structured parsing result: %s\n", apiKey)
		}
	}
	
	// Method 6: HAProxy-compatible approach
	fmt.Printf("\n🔍 METHOD 6: HAProxy-compatible extraction\n")
	fmt.Printf("Testing what HAProxy word() functions would return...\n")
	
	// Simulate HAProxy word(X, 'delim') function
	simulateHAProxyWord := func(text string, wordNum int, delim string) string {
		parts := strings.Split(text, delim)
		if wordNum > 0 && wordNum <= len(parts) {
			return parts[wordNum-1] // HAProxy is 1-indexed
		}
		return ""
	}
	
	fmt.Printf("word(1,'='): %s\n", simulateHAProxyWord(header, 1, "="))
	fmt.Printf("word(2,'='): %s\n", simulateHAProxyWord(header, 2, "="))
	fmt.Printf("word(3,'='): %s\n", simulateHAProxyWord(header, 3, "="))
	
	// Test what we actually get with current logic
	word2 := simulateHAProxyWord(header, 2, "=")
	word1FromThat := simulateHAProxyWord(word2, 1, "/")
	fmt.Printf("\nCurrent HAProxy logic result: %s\n", word1FromThat)
	
	// Why is it wrong?
	fmt.Printf("\n❌ PROBLEM IDENTIFIED:\n")
	fmt.Printf("word(2,'=') gets the 2nd part AFTER splitting by '='\n")
	fmt.Printf("But the 2nd part is: '%s'\n", simulateHAProxyWord(header, 2, "="))
	fmt.Printf("This is NOT the part after 'Credential='\n")
	
	// Correct approach for HAProxy
	fmt.Printf("\n✅ CORRECT HAPROXY APPROACH:\n")
	fmt.Printf("We need to find specifically the part after 'Credential='\n")
	fmt.Printf("Options:\n")
	fmt.Printf("1. Use regex if HAProxy supports it properly\n")
	fmt.Printf("2. Use substring functions if available\n") 
	fmt.Printf("3. Use a different parsing strategy\n")
	fmt.Printf("4. Pre-process with Lua script\n")
	
	// Test if we can work around it
	fmt.Printf("\n🛠️ WORKAROUND TEST:\n")
	// What if we split by "Credential=" first?
	if strings.Contains(header, "Credential=") {
		parts := strings.Split(header, "Credential=")
		if len(parts) > 1 {
			afterCredential := parts[1]
			fmt.Printf("After splitting by 'Credential=': %s\n", afterCredential)
			
			// Now get part before comma and slash
			beforeComma := strings.Split(afterCredential, ",")[0]
			apiKey := strings.Split(beforeComma, "/")[0]
			fmt.Printf("Final API key: %s\n", apiKey)
			
			fmt.Printf("\n💡 HAPROXY EQUIVALENT:\n")
			fmt.Printf("http-request set-var(txn.temp) req.hdr(Authorization),word(2,'Credential=')\n")
			fmt.Printf("http-request set-var(txn.api_key) var(txn.temp),word(1,',')\n") 
			fmt.Printf("http-request set-var(txn.api_key) var(txn.api_key),word(1,'/')\n")
		}
	}
}
