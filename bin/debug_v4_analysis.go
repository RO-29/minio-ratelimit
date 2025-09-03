package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
)

type ServiceAccount struct {
	AccessKey string `json:"access_key"`
	SecretKey string `json:"secret_key"`
	Group     string `json:"group"`
}

func main() {
	fmt.Printf("🔍 DEBUG: HAProxy AWS V4 Extraction\n")
	fmt.Printf("===================================\n\n")

	// Load real premium account
	data, _ := ioutil.ReadFile("../../config/generated_service_accounts.json")
	var accounts struct {
		ServiceAccounts []ServiceAccount `json:"service_accounts"`
	}
	json.Unmarshal(data, &accounts)
	
	var premium ServiceAccount
	for _, acc := range accounts.ServiceAccounts {
		if acc.Group == "premium" {
			premium = acc
			break
		}
	}

	// Create AWS V4 signed request
	sess, _ := session.NewSession(&aws.Config{
		Region:      aws.String("us-east-1"),
		Endpoint:    aws.String("http://127.0.0.1"),
		Credentials: credentials.NewStaticCredentials(premium.AccessKey, premium.SecretKey, ""),
		DisableSSL:  aws.Bool(true),
		S3ForcePathStyle: aws.Bool(true),
	})

	s3Client := s3.New(sess)
	req, _ := s3Client.PutObjectRequest(&s3.PutObjectInput{
		Bucket: aws.String("test-bucket"),
		Key:    aws.String("debug-test.txt"),
		Body:   bytes.NewReader([]byte("debug content")),
	})
	
	req.Sign()

	fmt.Printf("🔑 TESTING PREMIUM KEY: %s\n", premium.AccessKey)
	fmt.Printf("📤 AUTHORIZATION HEADER:\n%s\n\n", req.HTTPRequest.Header.Get("Authorization"))

	// Execute and get debug headers
	resp, err := http.DefaultClient.Do(req.HTTPRequest)
	if err != nil {
		fmt.Printf("❌ Error: %v\n", err)
		return
	}
	defer resp.Body.Close()

	fmt.Printf("📥 HAProxy DEBUG HEADERS:\n")
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
		if len(value) > 100 {
			value = value[:100] + "..."
		}
		fmt.Printf("  %s: %s\n", header, value)
	}

	fmt.Printf("\n📊 ANALYSIS:\n")
	expectedKey := premium.AccessKey
	actualKey := resp.Header.Get("X-Debug-Final-Key")
	
	fmt.Printf("  Expected API Key: %s\n", expectedKey)
	fmt.Printf("  Actual API Key:   %s\n", actualKey)
	
	if actualKey == expectedKey {
		fmt.Printf("  ✅ SUCCESS: API key extracted correctly!\n")
	} else {
		fmt.Printf("  ❌ FAILURE: API key extraction wrong\n")
		
		// Analyze what word(2,'=') is getting
		word2 := resp.Header.Get("X-Debug-Word2-Equals")
		fmt.Printf("\n🔍 DETAILED ANALYSIS:\n")
		fmt.Printf("  word(2,'=') returns: %s\n", word2)
		
		if len(word2) > 0 {
			// Manually parse what word(1,'/') would get from word2
			parts := []string{}
			current := ""
			for _, char := range word2 {
				if char == '/' {
					parts = append(parts, current)
					break
				}
				current += string(char)
			}
			if len(parts) == 0 && current != "" {
				parts = append(parts, current)
			}
			
			if len(parts) > 0 {
				fmt.Printf("  word(1,'/') from that should be: %s\n", parts[0])
				
				if parts[0] == expectedKey {
					fmt.Printf("  ✅ The logic SHOULD work - there's another issue!\n")
				} else {
					fmt.Printf("  ❌ The word() extraction is getting wrong data\n")
				}
			}
		}
	}
}
