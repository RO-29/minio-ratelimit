package main

import (
	"os"
	"testing"
)

func TestLoadServiceAccounts(t *testing.T) {
	// Create temporary test file
	tempFile, err := os.CreateTemp("", "test_accounts_*.json")
	if err != nil {
		t.Fatalf("Failed to create temp file: %v", err)
	}
	defer func() {
		if err := os.Remove(tempFile.Name()); err != nil {
			t.Logf("Failed to remove temp file: %v", err)
		}
	}()

	// Write test data to the file
	testContent := `{
		"service_accounts": [
			{
				"access_key": "test1",
				"secret_key": "secret1",
				"group": "basic"
			},
			{
				"access_key": "test2",
				"secret_key": "secret2",
				"group": "premium"
			}
		]
	}`
	if _, err := tempFile.Write([]byte(testContent)); err != nil {
		t.Fatalf("Failed to write to temp file: %v", err)
	}
	if err := tempFile.Close(); err != nil {
		t.Fatalf("Failed to close temp file: %v", err)
	}

	// Test loading accounts
	accounts, err := loadServiceAccounts(tempFile.Name())
	if err != nil {
		t.Fatalf("loadServiceAccounts returned error: %v", err)
	}

	// Validate accounts
	if len(accounts) != 2 {
		t.Errorf("Expected 2 accounts, got %d", len(accounts))
	}

	if accounts[0].AccessKey != "test1" || accounts[0].Group != "basic" {
		t.Errorf("First account data incorrect: %+v", accounts[0])
	}

	if accounts[1].AccessKey != "test2" || accounts[1].Group != "premium" {
		t.Errorf("Second account data incorrect: %+v", accounts[1])
	}
}

func TestLoadServiceAccountsError(t *testing.T) {
	// Test with non-existent file
	_, err := loadServiceAccounts("non_existent_file.json")
	if err == nil {
		t.Errorf("Expected error for non-existent file, got nil")
	}
}
