#!/bin/bash

echo "🚀 Direct ClickHouse Ingestion for MinIO Rate Limiting Data"
echo "=========================================================="

# Copy the JSON file into the container
docker cp comprehensive_results.json hyperdx:/tmp/comprehensive_results.json

# Create database and tables
echo "🔧 Creating database and tables..."
docker exec hyperdx clickhouse-client --multiquery --query "
CREATE DATABASE IF NOT EXISTS minio_logs;

CREATE TABLE IF NOT EXISTS minio_logs.test_results (
    timestamp DateTime64(3) DEFAULT now64(),
    test_id String,
    test_group LowCardinality(String),
    api_key String,
    method LowCardinality(String),
    requests_sent UInt32,
    success_count UInt32,
    rate_limited_count UInt32,
    error_count UInt32,
    avg_latency_ms Float64,
    auth_method LowCardinality(String),
    rate_limit_group LowCardinality(String),
    burst_hits UInt32,
    minute_hits UInt32,
    effective_limit UInt32,
    observed_bursts UInt32,
    success_rate Float64,
    raw_data JSON,
    rate_limit_details JSON,
    error_details JSON,
    header_captures JSON
) ENGINE = MergeTree()
ORDER BY (timestamp, test_group, api_key)
PARTITION BY toYYYYMM(timestamp);

CREATE TABLE IF NOT EXISTS minio_logs.test_summary (
    timestamp DateTime64(3) DEFAULT now64(),
    total_tests UInt32,
    duration_seconds Float64,
    total_requests UInt32,
    total_success UInt32,
    total_limited UInt32,
    total_errors UInt32,
    auth_methods JSON,
    summary_data JSON
) ENGINE = MergeTree()
ORDER BY timestamp;
"

echo "✅ Database and tables created!"

# Insert sample data directly with SQL commands
echo "📊 Inserting sample MinIO rate limiting data..."

# Insert summary data
docker exec hyperdx clickhouse-client --query "
INSERT INTO minio_logs.test_summary 
(total_tests, duration_seconds, total_requests, total_success, total_limited, total_errors, auth_methods, summary_data)
VALUES 
(36, 18.97, 2025, 0, 0, 2025, '{}', '{\"TotalTests\": 36, \"TotalRequests\": 2025, \"TotalSuccess\": 0, \"TotalLimited\": 0, \"TotalErrors\": 2025}')
"

# Insert group results for basic, standard, premium
docker exec hyperdx clickhouse-client --multiquery --query "
INSERT INTO minio_logs.test_results 
(test_group, api_key, method, requests_sent, success_count, rate_limited_count, error_count, avg_latency_ms, raw_data, error_details)
VALUES 
('basic', '', 'Combined', 675, 0, 0, 675, 332.0, '{\"Group\": \"basic\", \"RequestsSent\": 675}', '{\"Connection Refused (Server Down)\": 345}'),
('premium', '', 'Combined', 675, 0, 0, 675, 336.0, '{\"Group\": \"premium\", \"RequestsSent\": 675}', '{\"Connection Refused (Server Down)\": 345}'),
('standard', '', 'Combined', 675, 0, 0, 675, 341.0, '{\"Group\": \"standard\", \"RequestsSent\": 675}', '{\"Connection Refused (Server Down)\": 345}');
"

echo "✅ Sample data inserted successfully!"

echo "🔍 Verifying data ingestion..."
docker exec hyperdx clickhouse-client --query "
SELECT 
    'Test Results' as table_name, 
    count() as records 
FROM minio_logs.test_results 
UNION ALL 
SELECT 
    'Summary Records', 
    count() 
FROM minio_logs.test_summary
FORMAT PrettyCompact"

echo ""
echo "📋 Sample data preview:"
docker exec hyperdx clickhouse-client --query "
SELECT 
    test_group, 
    requests_sent, 
    success_count, 
    rate_limited_count, 
    avg_latency_ms
FROM minio_logs.test_results 
ORDER BY requests_sent DESC 
LIMIT 5
FORMAT PrettyCompact"

echo ""
echo "✅ Direct ingestion completed!"
echo "🎯 ClickHouse is ready for analysis queries"