package main

import (
	"fmt"
	"strings"
)

// Helper function for min - returns the minimum of two integers
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// categorizeError categorizes different types of errors for better analysis
func categorizeError(errorMsg string, statusCode int) string {
	switch {
	case statusCode == 400:
		return "Bad Request (Expected - Test Data)"
	case statusCode == 401:
		return "Unauthorized (Expected - Invalid Auth)"
	case statusCode == 403:
		return "Forbidden (Expected - No Permission)"
	case statusCode == 404:
		return "Not Found (Expected - Test Bucket)"
	case statusCode == 429:
		return "Rate Limited (Expected - Testing Limits)"
	case statusCode == 500:
		return "Server Error (Unexpected)"
	case strings.Contains(errorMsg, "connection refused"):
		return "Connection Refused (Server Down)"
	case strings.Contains(errorMsg, "timeout"):
		return "Timeout (Expected - Heavy Load)"
	case strings.Contains(errorMsg, "bucket does not exist"):
		return "Bucket Missing (Expected - Test Setup)"
	case strings.Contains(errorMsg, "context canceled"):
		return "Context Canceled (Expected - Test Timeout)"
	default:
		return fmt.Sprintf("Other Error: %s", errorMsg)
	}
}
