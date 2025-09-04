package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"strings"
	"time"
)

// Configuration for test execution
type TestConfig struct {
	Duration       time.Duration
	AccountsPerTier int
	StressPremium  bool
	TargetTiers    []string
	ExportJSON     bool
	OutputFile     string
	Verbose        bool
	ConfigFile     string
}

// Parse command-line flags
func parseFlags() TestConfig {
	config := TestConfig{}
	
	flag.DurationVar(&config.Duration, "duration", 120*time.Second, "Test duration (e.g., 60s, 2m, 5m)")
	flag.IntVar(&config.AccountsPerTier, "accounts", 3, "Number of accounts per tier to test")
	flag.BoolVar(&config.StressPremium, "stress-premium", false, "Stress test premium accounts to find actual limits")
	flag.BoolVar(&config.ExportJSON, "json", false, "Export detailed results to JSON file")
	flag.StringVar(&config.OutputFile, "output", "rate_limit_test_results.json", "Output file for JSON export")
	flag.BoolVar(&config.Verbose, "verbose", false, "Enable verbose logging")
	flag.StringVar(&config.ConfigFile, "config", "../../config/generated_service_accounts.json", "Path to service accounts config file")
	
	var tiersFlag string
	flag.StringVar(&tiersFlag, "tiers", "basic,standard,premium", "Comma-separated list of tiers to test (basic,standard,premium)")
	
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "MinIO Rate Limiting Comprehensive Test Suite\n\n")
		fmt.Fprintf(os.Stderr, "Usage: %s [options]\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "Examples:\n")
		fmt.Fprintf(os.Stderr, "  %s -duration=30s -accounts=2                    # Quick test\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s -stress-premium -duration=5m                # Stress test premium\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s -json -output=results.json                 # Export to JSON\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s -tiers=premium -accounts=5 -duration=10m    # Only premium, 5 accounts, 10 minutes\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "\nOptions:\n")
		flag.PrintDefaults()
	}
	
	flag.Parse()
	
	config.TargetTiers = strings.Split(tiersFlag, ",")
	for i, tier := range config.TargetTiers {
		config.TargetTiers[i] = strings.TrimSpace(tier)
	}
	
	return config
}

// Load service accounts from JSON configuration file
func loadServiceAccounts(configFile string) ([]ServiceAccount, error) {
	data, err := ioutil.ReadFile(configFile)
	if err != nil {
		return nil, err
	}

	var config struct {
		ServiceAccounts []ServiceAccount `json:"service_accounts"`
	}
	
	if err := json.Unmarshal(data, &config); err != nil {
		return nil, err
	}

	return config.ServiceAccounts, nil
}