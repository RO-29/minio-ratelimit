package main

import (
	"context"
	"fmt"
	"log"
	"time"
)

func main() {
	// Parse command-line flags
	config := parseFlags()
	
	if config.StressPremium {
		fmt.Printf("🚀 PREMIUM STRESS TEST - MinIO RATE LIMITING\n")
		fmt.Printf("=============================================\n")
		fmt.Printf("⏱️  Mode: Premium stress testing to find actual limits\n")
	} else {
		fmt.Printf("🚀 COMPREHENSIVE MinIO RATE LIMITING TEST\n")
		fmt.Printf("==========================================\n")
	}
	fmt.Printf("⏱️  Test Duration: %.0f seconds with real-time monitoring\n", config.Duration.Seconds())
	fmt.Printf("📊 Features: Burst testing, Header analysis, Rate limit insights\n")
	if config.ExportJSON {
		fmt.Printf("📋 JSON Export: %s\n", config.OutputFile)
	}
	fmt.Printf("\n")

	// Load service accounts
	accounts, err := loadServiceAccounts(config.ConfigFile)
	if err != nil {
		log.Fatal("Failed to load service accounts:", err)
	}

	// Select test accounts based on configuration
	testAccounts := selectTestAccountsForConfig(accounts, config)

	fmt.Printf("✅ Selected %d accounts for testing:\n", len(testAccounts))
	for group, count := range countByGroup(testAccounts) {
		fmt.Printf("   • %s: %d accounts\n", group, count)
	}
	fmt.Printf("\n")

	// Initialize progress tracker
	progress := &ProgressTracker{
		startTime:  time.Now(),
		lastUpdate: time.Now(),
	}

	// Test context with configurable timeout
	ctx, cancel := context.WithTimeout(context.Background(), config.Duration)
	defer cancel()

	// Start progress display goroutine
	go displayRealTimeProgress(ctx, progress)

	// Run tests based on configuration
	start := time.Now()
	var results []TestResult
	if config.StressPremium {
		results = runPremiumStressTests(ctx, testAccounts, progress, config)
	} else {
		results = runComprehensiveTests(ctx, testAccounts, progress)
	}
	duration := time.Since(start)

	fmt.Printf("\n\n🏁 TESTING COMPLETED IN %.1f seconds\n", duration.Seconds())
	fmt.Printf("📊 Processing results and generating comprehensive report...\n\n")

	// Generate comprehensive report
	summary := generateSummary(results, duration)
	printReport(summary)
	
	// Export JSON if requested
	if config.ExportJSON {
		exportToJSON(summary, results, config.OutputFile)
	}
}