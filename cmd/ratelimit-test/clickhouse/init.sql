-- Create database for MinIO logs
CREATE DATABASE IF NOT EXISTS minio_logs;

-- Use the minio_logs database
USE minio_logs;

-- Create table for comprehensive test results with proper JSON parsing
CREATE TABLE IF NOT EXISTS test_results
(
    `timestamp` DateTime64(3) DEFAULT now64(),
    `test_id` String,
    `group` LowCardinality(String),
    `api_key` String,
    `method` LowCardinality(String),
    `requests_sent` UInt32,
    `success_count` UInt32,
    `rate_limited_count` UInt32,
    `error_count` UInt32,
    `avg_latency_ms` Float64,
    `auth_method` LowCardinality(String),
    `rate_limit_group` LowCardinality(String),
    `burst_hits` UInt32,
    `minute_hits` UInt32,
    `limit_per_second` UInt32,
    `limit_per_minute` UInt32,
    `current_per_second` UInt32,
    `current_per_minute` UInt32,
    `reset_time` UInt64,
    `error_details` Map(String, UInt32),
    `header_captures` Array(String)
) ENGINE = MergeTree()
ORDER BY (timestamp, group, api_key)
PARTITION BY toYYYYMM(timestamp)
TTL timestamp + INTERVAL 90 DAY;

-- Create table for individual HTTP requests (detailed logs)
CREATE TABLE IF NOT EXISTS http_requests
(
    `timestamp` DateTime64(3) DEFAULT now64(),
    `request_id` String,
    `api_key` String,
    `group` LowCardinality(String),
    `method` LowCardinality(String),
    `path` String,
    `status_code` UInt16,
    `latency_ms` Float64,
    `auth_method` LowCardinality(String),
    `rate_limited` UInt8,
    `error_message` String,
    `user_agent` String,
    `source_ip` IPv4,
    `rate_limit_remaining_second` UInt32,
    `rate_limit_remaining_minute` UInt32,
    `request_size` UInt32,
    `response_size` UInt32,
    `headers` Map(String, String)
) ENGINE = MergeTree()
ORDER BY (timestamp, api_key, group)
PARTITION BY toYYYYMM(timestamp)
TTL timestamp + INTERVAL 30 DAY;

-- Create materialized view for real-time aggregations
CREATE MATERIALIZED VIEW IF NOT EXISTS test_summary_mv
ENGINE = SummingMergeTree()
ORDER BY (group, toStartOfHour(timestamp))
POPULATE AS
SELECT
    group,
    toStartOfHour(timestamp) as hour,
    sum(requests_sent) as total_requests,
    sum(success_count) as total_success,
    sum(rate_limited_count) as total_rate_limited,
    sum(error_count) as total_errors,
    avg(avg_latency_ms) as avg_latency,
    count() as test_runs
FROM test_results
GROUP BY group, toStartOfHour(timestamp);

-- Create view for rate limiting analysis
CREATE VIEW IF NOT EXISTS rate_limit_analysis AS
SELECT
    group,
    api_key,
    auth_method,
    count() as total_tests,
    sum(requests_sent) as total_requests,
    sum(success_count) as total_success,
    sum(rate_limited_count) as total_rate_limited,
    sum(error_count) as total_errors,
    round(avg(avg_latency_ms), 2) as avg_latency_ms,
    round(sum(rate_limited_count) / sum(requests_sent) * 100, 2) as rate_limit_percentage,
    round(sum(success_count) / sum(requests_sent) * 100, 2) as success_percentage
FROM test_results
WHERE requests_sent > 0
GROUP BY group, api_key, auth_method
ORDER BY rate_limit_percentage DESC;

-- Create view for performance metrics by group
CREATE VIEW IF NOT EXISTS performance_by_group AS
SELECT
    group,
    count() as test_count,
    sum(requests_sent) as total_requests,
    round(avg(avg_latency_ms), 2) as avg_latency_ms,
    round(quantile(0.5)(avg_latency_ms), 2) as p50_latency_ms,
    round(quantile(0.95)(avg_latency_ms), 2) as p95_latency_ms,
    round(quantile(0.99)(avg_latency_ms), 2) as p99_latency_ms,
    round(sum(rate_limited_count) / sum(requests_sent) * 100, 2) as rate_limit_percentage,
    round(sum(success_count) / sum(requests_sent) * 100, 2) as success_percentage
FROM test_results
WHERE requests_sent > 0
GROUP BY group
ORDER BY avg_latency_ms;

-- Create view for time-series analysis
CREATE VIEW IF NOT EXISTS hourly_metrics AS
SELECT
    toStartOfHour(timestamp) as hour,
    group,
    count() as test_runs,
    sum(requests_sent) as requests,
    sum(success_count) as success,
    sum(rate_limited_count) as rate_limited,
    sum(error_count) as errors,
    round(avg(avg_latency_ms), 2) as avg_latency
FROM test_results
GROUP BY toStartOfHour(timestamp), group
ORDER BY hour DESC, group;

-- Insert sample queries for HyperDX dashboards
CREATE TABLE IF NOT EXISTS dashboard_queries
(
    `query_name` String,
    `description` String,
    `sql_query` String,
    `created_at` DateTime DEFAULT now()
) ENGINE = Memory;

INSERT INTO dashboard_queries VALUES
('Rate Limiting Overview', 'Overall rate limiting statistics by group', 'SELECT group, sum(total_requests) as requests, sum(total_rate_limited) as rate_limited, round(sum(total_rate_limited)/sum(total_requests)*100, 2) as rate_limit_pct FROM test_summary_mv WHERE hour >= now() - INTERVAL 24 HOUR GROUP BY group ORDER BY rate_limit_pct DESC'),
('Performance Trends', 'Latency trends over time by group', 'SELECT hour, group, avg_latency FROM hourly_metrics WHERE hour >= now() - INTERVAL 24 HOUR ORDER BY hour DESC'),
('Top Rate Limited APIs', 'APIs with highest rate limiting', 'SELECT api_key, group, total_requests, total_rate_limited, rate_limit_percentage FROM rate_limit_analysis WHERE total_requests > 10 ORDER BY rate_limit_percentage DESC LIMIT 20'),
('Error Analysis', 'Breakdown of errors by type and group', 'SELECT group, arrayJoin(mapKeys(error_details)) as error_type, sum(mapValues(error_details)) as error_count FROM test_results WHERE length(error_details) > 0 GROUP BY group, error_type ORDER BY error_count DESC');

-- Grant permissions
GRANT ALL ON minio_logs.* TO default;