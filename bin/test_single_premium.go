package main

import (
	"bytes"
	"encoding/json"
	"fmt" 
	"io/ioutil"
	"net/http"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
)

type ServiceAccount struct {
	AccessKey   string `json:"access_key"`
	SecretKey   string `json:"secret_key"`
	Group       string `json:"group"`
	Created     string `json:"created"`
	Description string `json:"description"`
	Policy      string `json:"policy"`
}

type ServiceAccountsFile struct {
	ServiceAccounts []ServiceAccount `json:"service_accounts"`
}

func main() {
	// Load real credentials
	data, err := ioutil.ReadFile("../../config/generated_service_accounts.json")
	if err != nil {
		fmt.Printf("Error loading credentials: %v\n", err)
		return
	}

	var accounts ServiceAccountsFile
	json.Unmarshal(data, &accounts)

	// Get first premium account
	var premiumAccount ServiceAccount
	for _, acc := range accounts.ServiceAccounts {
		if acc.Group == "premium" {
			premiumAccount = acc
			break
		}
	}

	fmt.Printf("🔑 Using Premium API Key: %s\n", premiumAccount.AccessKey)
	fmt.Printf("📊 Testing rate limiting with REAL AWS signatures\n\n")

	// Create AWS session
	sess, err := session.NewSession(&aws.Config{
		Region:      aws.String("us-east-1"),
		Endpoint:    aws.String("http://localhost"),
		Credentials: credentials.NewStaticCredentials(premiumAccount.AccessKey, premiumAccount.SecretKey, ""),
		DisableSSL:  aws.Bool(true),
		S3ForcePathStyle: aws.Bool(true),
	})
	if err != nil {
		fmt.Printf("Error creating session: %v\n", err)
		return
	}

	s3Client := s3.New(sess)

	// Test successful request
	fmt.Println("1️⃣ SUCCESSFUL REQUEST - Premium Key (should work)")
	fmt.Println("=" + fmt.Sprintf("%*s", 60, ""))

	objectKey := fmt.Sprintf("premium-test-%d.txt", time.Now().Unix())
	content := "Premium tier test content with real AWS signature"

	fmt.Printf("PUT Object: %s\n", objectKey)
	fmt.Printf("Bucket: test-bucket\n")
	fmt.Printf("Content: %s\n\n", content)

	// Perform the request and capture the full HTTP exchange
	req, _ := s3Client.PutObjectRequest(&s3.PutObjectInput{
		Bucket: aws.String("test-bucket"),
		Key:    aws.String(objectKey),
		Body:   bytes.NewReader([]byte(content)),
	})
	
	// Sign the request
	req.Sign()

	fmt.Println("📤 REQUEST HEADERS:")
	for name, values := range req.HTTPRequest.Header {
		for _, value := range values {
			fmt.Printf("  %s: %s\n", name, value)
		}
	}

	// Execute request
	resp, err := http.DefaultClient.Do(req.HTTPRequest)
	if resp != nil {
		fmt.Printf("\n📥 RESPONSE STATUS: %s\n", resp.Status)
		fmt.Println("📥 RESPONSE HEADERS:")
		for name, values := range resp.Header {
			for _, value := range values {
				fmt.Printf("  %s: %s\n", name, value)
			}
		}
		resp.Body.Close()
	}

	if err != nil {
		fmt.Printf("Error: %v\n", err)
	}

	fmt.Println("\n" + "=" + fmt.Sprintf("%*s", 60, ""))
	fmt.Println("✅ Premium request completed - check X-RateLimit headers above")
	fmt.Printf("✅ Rate limit should show: 2000 requests/minute for premium tier\n")
}
