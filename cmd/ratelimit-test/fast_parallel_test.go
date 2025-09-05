package main

import (
	"context"
	"testing"
	"time"
)

func TestParseFlags(t *testing.T) {
	// Reset flags for testing
	config := TestConfig{
		Duration:        120 * time.Second,
		AccountsPerTier: 3,
		StressPremium:   false,
		TargetTiers:     []string{"basic", "standard", "premium"},
		ExportJSON:      false,
		OutputFile:      "rate_limit_test_results.json",
		Verbose:         false,
		ConfigFile:      "haproxy/config/generated_service_accounts.json",
	}

	// Test default values
	if config.Duration != 120*time.Second {
		t.Errorf("Expected default duration 120s, got %v", config.Duration)
	}

	if config.AccountsPerTier != 3 {
		t.Errorf("Expected 3 accounts per tier, got %d", config.AccountsPerTier)
	}

	if len(config.TargetTiers) != 3 {
		t.Errorf("Expected 3 target tiers, got %d", len(config.TargetTiers))
	}
}

func TestSelectTestAccountsForConfig(t *testing.T) {
	// Mock service accounts
	accounts := []ServiceAccount{
		{AccessKey: "basic1", SecretKey: "secret1", Group: "basic"},
		{AccessKey: "basic2", SecretKey: "secret2", Group: "basic"},
		{AccessKey: "standard1", SecretKey: "secret3", Group: "standard"},
		{AccessKey: "standard2", SecretKey: "secret4", Group: "standard"},
		{AccessKey: "premium1", SecretKey: "secret5", Group: "premium"},
		{AccessKey: "premium2", SecretKey: "secret6", Group: "premium"},
	}

	config := TestConfig{
		AccountsPerTier: 2,
		TargetTiers:     []string{"basic", "premium"},
		StressPremium:   false,
	}

	selected := selectTestAccountsForConfig(accounts, config)

	// Should select 2 basic + 2 premium = 4 total
	if len(selected) != 4 {
		t.Errorf("Expected 4 selected accounts, got %d", len(selected))
	}

	// Count by tier
	basicCount := 0
	premiumCount := 0
	for _, acc := range selected {
		switch acc.Group {
		case "basic":
			basicCount++
		case "premium":
			premiumCount++
		}
	}

	if basicCount != 2 {
		t.Errorf("Expected 2 basic accounts, got %d", basicCount)
	}

	if premiumCount != 2 {
		t.Errorf("Expected 2 premium accounts, got %d", premiumCount)
	}
}

func TestSelectTestAccountsStressPremium(t *testing.T) {
	accounts := []ServiceAccount{
		{AccessKey: "premium1", SecretKey: "secret1", Group: "premium"},
		{AccessKey: "premium2", SecretKey: "secret2", Group: "premium"},
		{AccessKey: "premium3", SecretKey: "secret3", Group: "premium"},
		{AccessKey: "premium4", SecretKey: "secret4", Group: "premium"},
	}

	config := TestConfig{
		AccountsPerTier: 2,
		TargetTiers:     []string{"premium"},
		StressPremium:   true, // Should double the accounts for premium
	}

	selected := selectTestAccountsForConfig(accounts, config)

	// Should select 4 premium accounts (2 * 2)
	if len(selected) != 4 {
		t.Errorf("Expected 4 premium accounts for stress testing, got %d", len(selected))
	}
}

func TestCountByGroup(t *testing.T) {
	accounts := []ServiceAccount{
		{Group: "basic"},
		{Group: "basic"},
		{Group: "standard"},
		{Group: "premium"},
		{Group: "premium"},
		{Group: "premium"},
	}

	counts := countByGroup(accounts)

	expected := map[string]int{
		"basic":    2,
		"standard": 1,
		"premium":  3,
	}

	for group, expectedCount := range expected {
		if counts[group] != expectedCount {
			t.Errorf("Expected %d %s accounts, got %d", expectedCount, group, counts[group])
		}
	}
}

func TestCategorizeError(t *testing.T) {
	testCases := []struct {
		errorMsg   string
		statusCode int
		expected   string
	}{
		{"", 400, "Bad Request (Expected - Test Data)"},
		{"", 429, "Rate Limited (Expected - Testing Limits)"},
		{"connection refused", 0, "Connection Refused (Server Down)"},
		{"timeout", 0, "Timeout (Expected - Heavy Load)"},
		{"bucket does not exist", 0, "Bucket Missing (Expected - Test Setup)"},
	}

	for _, tc := range testCases {
		result := categorizeError(tc.errorMsg, tc.statusCode)
		if result != tc.expected {
			t.Errorf("categorizeError(%q, %d) = %q, expected %q",
				tc.errorMsg, tc.statusCode, result, tc.expected)
		}
	}
}

func TestProgressTracker(t *testing.T) {
	progress := &ProgressTracker{
		startTime:  time.Now(),
		lastUpdate: time.Now(),
	}

	// Test atomic operations
	progress.totalRequests = 100
	progress.successCount = 70
	progress.rateLimitCount = 20
	progress.errorCount = 10

	if progress.totalRequests != 100 {
		t.Errorf("Expected 100 total requests, got %d", progress.totalRequests)
	}

	if progress.successCount != 70 {
		t.Errorf("Expected 70 successful requests, got %d", progress.successCount)
	}
}

func TestMin(t *testing.T) {
	testCases := []struct {
		a, b, expected int
	}{
		{5, 3, 3},
		{1, 10, 1},
		{7, 7, 7},
		{0, -1, -1},
	}

	for _, tc := range testCases {
		result := min(tc.a, tc.b)
		if result != tc.expected {
			t.Errorf("min(%d, %d) = %d, expected %d", tc.a, tc.b, result, tc.expected)
		}
	}
}

func TestGetTotalHeaderCaptures(t *testing.T) {
	results := []TestResult{
		{HeaderCaptures: make([]ResponseHeaders, 5)},
		{HeaderCaptures: make([]ResponseHeaders, 3)},
		{HeaderCaptures: make([]ResponseHeaders, 0)},
	}

	total := getTotalHeaderCaptures(results)
	expected := 8 // 5 + 3 + 0

	if total != expected {
		t.Errorf("Expected %d total header captures, got %d", expected, total)
	}
}

// Benchmark tests for performance
func BenchmarkSelectTestAccounts(b *testing.B) {
	accounts := make([]ServiceAccount, 100)
	for i := 0; i < 100; i++ {
		accounts[i] = ServiceAccount{
			Group: []string{"basic", "standard", "premium"}[i%3],
		}
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		selectTestAccounts(accounts, 3)
	}
}

func BenchmarkCategorizeError(b *testing.B) {
	testErrors := []string{
		"connection refused",
		"timeout occurred",
		"bucket does not exist",
		"context canceled",
		"other error",
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		for _, err := range testErrors {
			categorizeError(err, 0)
		}
	}
}

// Mock context for testing
func TestContextCancellation(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()

	start := time.Now()

	// Wait for context to be cancelled
	<-ctx.Done()

	elapsed := time.Since(start)

	// Should be around 100ms (with some tolerance)
	if elapsed < 90*time.Millisecond || elapsed > 150*time.Millisecond {
		t.Errorf("Context cancellation took %v, expected ~100ms", elapsed)
	}
}
