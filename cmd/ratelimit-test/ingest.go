package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"time"

	_ "github.com/ClickHouse/clickhouse-go/v2"
)

const (
	clickhouseDSN = "http://api:api@127.0.0.1:8123/minio_logs"
	jsonFilePath  = "comprehensive_results.json"
)

// ComprehensiveResults represents the structure of the comprehensive_results.json
type ComprehensiveResults struct {
	Summary         json.RawMessage `json:"summary"`
	DetailedResults []json.RawMessage `json:"detailed_results"`
	ExportTime      time.Time       `json:"export_time"`
	Version         string          `json:"version"`
}

func main() {
	// Connect to ClickHouse
	db, err := sql.Open("clickhouse", clickhouseDSN)
	if err != nil {
		log.Fatalf("Failed to connect to ClickHouse: %v", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Fatalf("Failed to ping ClickHouse: %v", err)
	}
	fmt.Println("Successfully connected to ClickHouse!")

	// Setup database and tables
	if err := setupDatabase(db); err != nil {
		log.Fatalf("Failed to setup database: %v", err)
	}

	// Ingest data
	if err := ingestData(db, jsonFilePath); err != nil {
		log.Fatalf("Failed to ingest data: %v", err)
	}

	fmt.Println("Data ingestion complete!")
}

func setupDatabase(db *sql.DB) error {
	fmt.Println("Setting up ClickHouse database and tables...")

	// Create database
	_, err := db.Exec("CREATE DATABASE IF NOT EXISTS minio_logs")
	if err != nil {
		return fmt.Errorf("failed to create database: %w", err)
	}

	// Create detailed results table
	detailedResultsTableSQL := `
	CREATE TABLE IF NOT EXISTS minio_logs.minio_ratelimit_test_results (
		timestamp DateTime64(3),
		api_key String,
		test_group LowCardinality(String),
		method LowCardinality(String),
		requests_sent UInt32,
		success UInt32,
		rate_limited UInt32,
		errors UInt32,
		avg_latency_ms Float64,
		raw_json JSON
	) ENGINE = MergeTree()
	ORDER BY (timestamp, test_group, api_key)
	PARTITION BY toYYYYMM(timestamp)
	TTL timestamp + INTERVAL 90 DAY;
	`
	_, err = db.Exec(detailedResultsTableSQL)
	if err != nil {
		return fmt.Errorf("failed to create minio_ratelimit_test_results table: %w", err)
	}

	// Create summary table
	summaryTableSQL := `
	CREATE TABLE IF NOT EXISTS minio_logs.minio_ratelimit_summary (
		timestamp DateTime64(3),
		total_tests UInt32,
		duration_ns UInt64,
		total_requests UInt32,
		total_success UInt32,
		total_limited UInt32,
		total_errors UInt32,
		raw_json JSON
	) ENGINE = MergeTree()
	ORDER BY timestamp
	PARTITION BY toYYYYMM(timestamp)
	TTL timestamp + INTERVAL 180 DAY;
	`
	_, err = db.Exec(summaryTableSQL)
	if err != nil {
		return fmt.Errorf("failed to create minio_ratelimit_summary table: %w", err)
	}

	fmt.Println("Database setup complete!")
	return nil
}

func ingestData(db *sql.DB, filePath string) error {
	fmt.Printf("Ingesting data from %s...\n", filePath)

	data, err := ioutil.ReadFile(filePath)
	if err != nil {
		return fmt.Errorf("failed to read JSON file: %w", err)
	}

	var results ComprehensiveResults
	if err := json.Unmarshal(data, &results); err != nil {
		return fmt.Errorf("failed to unmarshal JSON: %w", err)
	}

	// Ingest summary
	if err := ingestSummary(db, results.ExportTime, results.Summary); err != nil {
		return fmt.Errorf("failed to ingest summary: %w", err)
	}

	// Ingest detailed results
	if err := ingestDetailedResults(db, results.ExportTime, results.DetailedResults); err != nil {
		return fmt.Errorf("failed to ingest detailed results: %w", err)
	}

	fmt.Println("Data ingestion successful!")
	return nil
}

func ingestSummary(db *sql.DB, exportTime time.Time, summary json.RawMessage) error {
	var s struct {
		TotalTests    uint32 `json:"TotalTests"`
		Duration      uint64 `json:"Duration"` // nanoseconds
		TotalRequests uint32 `json:"TotalRequests"`
		TotalSuccess  uint32 `json:"TotalSuccess"`
		TotalLimited  uint32 `json:"TotalLimited"`
		TotalErrors   uint32 `json:"TotalErrors"`
	}
	if err := json.Unmarshal(summary, &s); err != nil {
		return fmt.Errorf("failed to unmarshal summary: %w", err)
	}

	tx, err := db.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback() // Rollback on error

	stmt, err := tx.Prepare("INSERT INTO minio_logs.minio_ratelimit_summary (timestamp, total_tests, duration_ns, total_requests, total_success, total_limited, total_errors, raw_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
	if err != nil {
		return fmt.Errorf("failed to prepare summary insert statement: %w", err)
	}
	defer stmt.Close()

	_, err = stmt.Exec(
		exportTime,
		s.TotalTests,
		s.Duration,
		s.TotalRequests,
		s.TotalSuccess,
		s.TotalLimited,
		s.TotalErrors,
		summary, // Store the entire raw JSON
	)
	if err != nil {
		return fmt.Errorf("failed to execute summary insert: %w", err)
	}

	return tx.Commit()
}

func ingestDetailedResults(db *sql.DB, exportTime time.Time, detailedResults []json.RawMessage) error {
	tx, err := db.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback() // Rollback on error

	stmt, err := tx.Prepare("INSERT INTO minio_logs.minio_ratelimit_test_results (timestamp, api_key, test_group, method, requests_sent, success, rate_limited, errors, avg_latency_ms, raw_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
	if err != nil {
		return fmt.Errorf("failed to prepare detailed results insert statement: %w", err)
	}
	defer stmt.Close()

	for _, result := range detailedResults {
		var dr struct {
			APIKey       string  `json:"APIKey"`
			Group        string  `json:"Group"`
			Method       string  `json:"Method"`
			RequestsSent uint32  `json:"RequestsSent"`
			Success      uint32  `json:"Success"`
			RateLimited  uint32  `json:"RateLimited"`
			Errors       uint32  `json:"Errors"`
			AvgLatencyMs float64 `json:"AvgLatencyMs"`
		}
		if err := json.Unmarshal(result, &dr); err != nil {
			return fmt.Errorf("failed to unmarshal detailed result: %w", err)
		}

		_, err = stmt.Exec(
			exportTime,
			dr.APIKey,
			dr.Group,
			dr.Method,
			dr.RequestsSent,
			dr.Success,
			dr.RateLimited,
			dr.Errors,
			dr.AvgLatencyMs,
			result, // Store the entire raw JSON
		)
		if err != nil {
			return fmt.Errorf("failed to execute detailed result insert: %w", err)
		}
	}

	return tx.Commit()
}
