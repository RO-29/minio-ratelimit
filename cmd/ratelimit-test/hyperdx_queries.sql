-- HyperDX ClickHouse Analysis Queries for MinIO Rate Limiting
-- Optimized for ClickHouse 25.8+ JSON capabilities and comprehensive_results.json structure

-- ============================================================================
-- BASIC OVERVIEW QUERIES
-- ============================================================================

-- 1. System Health Overview
SELECT 
    'Total Test Groups' as metric,
    toString(count(DISTINCT test_group)) as value
FROM minio_logs.test_results
UNION ALL
SELECT 
    'Total Requests Processed',
    toString(sum(requests_sent))
FROM minio_logs.test_results
UNION ALL
SELECT 
    'Overall Success Rate %',
    toString(round(sum(success_count) / sum(requests_sent) * 100, 2))
FROM minio_logs.test_results
UNION ALL
SELECT 
    'Rate Limiting Impact %',
    toString(round(sum(rate_limited_count) / sum(requests_sent) * 100, 2))
FROM minio_logs.test_results
FORMAT PrettyCompact;

-- 2. Performance by Group (Main Dashboard Query)
SELECT 
    test_group,
    sum(requests_sent) as total_requests,
    sum(success_count) as successful,
    sum(rate_limited_count) as rate_limited,
    sum(error_count) as errors,
    round(avg(avg_latency_ms), 2) as avg_latency_ms,
    round(sum(success_count) / sum(requests_sent) * 100, 2) as success_rate_pct,
    round(sum(rate_limited_count) / sum(requests_sent) * 100, 2) as rate_limit_pct,
    max(effective_limit) as configured_limit,
    sum(observed_bursts) as total_bursts
FROM minio_logs.test_results
GROUP BY test_group
ORDER BY total_requests DESC
FORMAT JSONEachRow;

-- ============================================================================
-- JSON-POWERED ADVANCED ANALYSIS
-- ============================================================================

-- 3. Deep Error Analysis using JSON functions
SELECT 
    test_group,
    JSON_EXTRACT_KEYS(error_details) as error_types,
    JSON_LENGTH(error_details) as error_type_count,
    sum(error_count) as total_errors
FROM minio_logs.test_results 
WHERE JSON_LENGTH(error_details) > 0
GROUP BY test_group, error_details
ORDER BY total_errors DESC
FORMAT PrettyCompact;

-- 4. Rate Limit Details Analysis (using nested JSON)
SELECT 
    test_group,
    JSON_VALUE(rate_limit_details, '$.LimitPerSecond') as limit_per_second,
    JSON_VALUE(rate_limit_details, '$.LimitPerMinute') as limit_per_minute,
    JSON_VALUE(rate_limit_details, '$.CurrentPerSecond') as current_per_second,
    JSON_VALUE(rate_limit_details, '$.CurrentPerMinute') as current_per_minute,
    rate_limited_count,
    CASE 
        WHEN JSON_VALUE(rate_limit_details, '$.LimitPerMinute') > 0 
        THEN round(JSON_VALUE(rate_limit_details, '$.CurrentPerMinute') / JSON_VALUE(rate_limit_details, '$.LimitPerMinute') * 100, 2)
        ELSE 0 
    END as utilization_pct
FROM minio_logs.test_results 
WHERE rate_limited_count > 0
ORDER BY utilization_pct DESC
FORMAT PrettyCompact;

-- 5. Throttle Events Time Series (for HyperDX charts)
SELECT 
    toStartOfMinute(timestamp) as minute,
    test_group,
    count() as throttle_events,
    avg(remaining_requests) as avg_remaining,
    avg(reset_in_seconds) as avg_reset_time
FROM minio_logs.throttle_events
WHERE timestamp >= now() - INTERVAL 1 HOUR
GROUP BY minute, test_group
ORDER BY minute DESC
FORMAT JSONEachRow;

-- ============================================================================
-- PERFORMANCE ANALYSIS QUERIES
-- ============================================================================

-- 6. Latency Percentiles by Group
SELECT 
    test_group,
    round(quantile(0.50)(avg_latency_ms), 2) as p50_latency_ms,
    round(quantile(0.75)(avg_latency_ms), 2) as p75_latency_ms,
    round(quantile(0.90)(avg_latency_ms), 2) as p90_latency_ms,
    round(quantile(0.95)(avg_latency_ms), 2) as p95_latency_ms,
    round(quantile(0.99)(avg_latency_ms), 2) as p99_latency_ms,
    round(max(avg_latency_ms), 2) as max_latency_ms
FROM minio_logs.test_results
WHERE requests_sent > 0
GROUP BY test_group
ORDER BY p95_latency_ms
FORMAT JSONEachRow;

-- 7. Burst Analysis (using JSON array processing)
SELECT 
    test_group,
    sum(observed_bursts) as total_observed_bursts,
    avg(effective_limit) as avg_effective_limit,
    round(sum(observed_bursts) / avg(effective_limit), 2) as burst_ratio,
    count() as test_runs,
    CASE 
        WHEN sum(observed_bursts) > avg(effective_limit) * 2 THEN 'High Burst Activity'
        WHEN sum(observed_bursts) > avg(effective_limit) THEN 'Moderate Burst Activity'
        ELSE 'Low Burst Activity'
    END as burst_level
FROM minio_logs.test_results
WHERE observed_bursts > 0
GROUP BY test_group
ORDER BY burst_ratio DESC
FORMAT PrettyCompact;

-- ============================================================================
-- REAL-TIME MONITORING QUERIES (for HyperDX dashboards)
-- ============================================================================

-- 8. Live Request Rate Monitoring
SELECT 
    toStartOfMinute(timestamp) as time_window,
    test_group,
    sum(requests_sent) / 60 as requests_per_second,
    sum(success_count) / 60 as success_per_second,
    sum(rate_limited_count) / 60 as rate_limited_per_second,
    round(avg(avg_latency_ms), 2) as avg_latency
FROM minio_logs.test_results
WHERE timestamp >= now() - INTERVAL 10 MINUTE
GROUP BY time_window, test_group
ORDER BY time_window DESC, requests_per_second DESC
FORMAT JSONEachRow;

-- 9. Authentication Method Effectiveness
SELECT 
    auth_method,
    test_group,
    count() as usage_count,
    sum(requests_sent) as total_requests,
    round(avg(success_rate), 2) as avg_success_rate,
    round(avg(avg_latency_ms), 2) as avg_latency,
    sum(rate_limited_count) as total_rate_limited
FROM minio_logs.test_results
WHERE auth_method != ''
GROUP BY auth_method, test_group
ORDER BY usage_count DESC
FORMAT JSONEachRow;

-- ============================================================================
-- ADVANCED JSON QUERIES FOR DEEP ANALYSIS
-- ============================================================================

-- 10. Extract Error Details with JSON path queries
SELECT 
    test_group,
    JSON_EXTRACT_STRING(raw_data, '$.ErrorDetails') as error_details_json,
    mapKeys(JSON_EXTRACT(error_details, '$')) as error_types,
    sum(error_count) as total_errors,
    round(avg(avg_latency_ms), 2) as avg_latency_during_errors
FROM minio_logs.test_results 
WHERE error_count > 0
GROUP BY test_group, error_details
ORDER BY total_errors DESC
FORMAT PrettyCompact;

-- 11. Header Captures Analysis (if present)
SELECT 
    test_group,
    JSON_LENGTH(header_captures) as header_count,
    count() as tests_with_headers,
    round(avg(success_rate), 2) as avg_success_with_headers
FROM minio_logs.test_results 
WHERE JSON_LENGTH(header_captures) > 0
GROUP BY test_group
ORDER BY header_count DESC
FORMAT PrettyCompact;

-- 12. Raw Data JSON Field Analysis
SELECT 
    test_group,
    JSON_VALUE(raw_data, '$.Method') as test_method,
    JSON_VALUE(raw_data, '$.RateLimitGroup') as rate_limit_group,
    JSON_VALUE(raw_data, '$.BurstHits') as burst_hits,
    JSON_VALUE(raw_data, '$.MinuteHits') as minute_hits,
    requests_sent,
    success_count,
    rate_limited_count
FROM minio_logs.test_results
WHERE JSON_HAS(raw_data, '$.Method')
ORDER BY burst_hits DESC
FORMAT JSONEachRow;

-- ============================================================================
-- HYPERDX DASHBOARD QUERIES (optimized for visualization)
-- ============================================================================

-- 13. Time Series for Success Rate Chart
SELECT 
    timestamp,
    test_group,
    round(success_count / requests_sent * 100, 2) as success_rate,
    requests_sent,
    avg_latency_ms
FROM minio_logs.test_results
WHERE requests_sent > 0
ORDER BY timestamp
FORMAT JSONEachRow;

-- 14. Heatmap Data for Rate Limiting Impact
SELECT 
    test_group as x_axis,
    'Rate Limited %' as y_axis,
    round(sum(rate_limited_count) / sum(requests_sent) * 100, 2) as value,
    sum(rate_limited_count) as absolute_value
FROM minio_logs.test_results
GROUP BY test_group
UNION ALL
SELECT 
    test_group as x_axis,
    'Error %' as y_axis,
    round(sum(error_count) / sum(requests_sent) * 100, 2) as value,
    sum(error_count) as absolute_value
FROM minio_logs.test_results
GROUP BY test_group
ORDER BY x_axis, y_axis
FORMAT JSONEachRow;

-- 15. Summary Statistics for Executive Dashboard
WITH summary AS (
    SELECT 
        sum(requests_sent) as total_requests,
        sum(success_count) as total_success,
        sum(rate_limited_count) as total_rate_limited,
        sum(error_count) as total_errors,
        avg(avg_latency_ms) as overall_avg_latency,
        count(DISTINCT test_group) as unique_groups,
        max(timestamp) as latest_test
    FROM minio_logs.test_results
)
SELECT 
    'requests' as metric_type, 'Total Processed' as metric_name, total_requests as value FROM summary
UNION ALL
SELECT 
    'percentage' as metric_type, 'Success Rate %' as metric_name, round(total_success/total_requests*100, 2) as value FROM summary
UNION ALL
SELECT 
    'percentage' as metric_type, 'Rate Limited %' as metric_name, round(total_rate_limited/total_requests*100, 2) as value FROM summary
UNION ALL
SELECT 
    'latency' as metric_type, 'Average Latency (ms)' as metric_name, round(overall_avg_latency, 2) as value FROM summary
UNION ALL
SELECT 
    'count' as metric_type, 'Test Groups' as metric_name, unique_groups as value FROM summary
FORMAT JSONEachRow;

-- ============================================================================
-- CAPACITY PLANNING QUERIES
-- ============================================================================

-- 16. Peak Load Analysis
SELECT 
    test_group,
    max(requests_sent) as peak_requests,
    max(observed_bursts) as peak_bursts,
    max(effective_limit) as configured_limit,
    round(max(requests_sent) / max(effective_limit), 2) as load_factor,
    CASE 
        WHEN max(requests_sent) > max(effective_limit) * 2 THEN 'Over Capacity'
        WHEN max(requests_sent) > max(effective_limit) * 1.5 THEN 'Near Capacity'
        ELSE 'Within Capacity'
    END as capacity_status
FROM minio_logs.test_results
WHERE effective_limit > 0
GROUP BY test_group
ORDER BY load_factor DESC
FORMAT PrettyCompact;

-- 17. Throttle Event Patterns (for alerting)
SELECT 
    test_group,
    toStartOfHour(timestamp) as hour,
    count() as throttle_count,
    avg(remaining_requests) as avg_remaining,
    min(remaining_requests) as min_remaining,
    round(avg(reset_in_seconds), 2) as avg_reset_time
FROM minio_logs.throttle_events
WHERE timestamp >= now() - INTERVAL 24 HOUR
GROUP BY test_group, hour
HAVING throttle_count > 10  -- Alert threshold
ORDER BY throttle_count DESC
FORMAT JSONEachRow;

-- ============================================================================
-- JSON AGGREGATION FUNCTIONS (ClickHouse 25.8+ features)
-- ============================================================================

-- 18. Aggregate JSON Data for Complex Analysis
SELECT 
    test_group,
    groupArray(JSON_VALUE(raw_data, '$.Method')) as methods_used,
    groupArray(avg_latency_ms) as latency_distribution,
    JSONExtract(groupArray((test_group, success_rate)), 'Array(Tuple(String, Float64))') as group_success_rates
FROM minio_logs.test_results
GROUP BY test_group
FORMAT JSONEachRow;

-- 19. Error Pattern Mining using JSON
SELECT 
    JSON_EXTRACT_KEYS(error_details) as error_pattern,
    count() as frequency,
    groupArray(test_group) as affected_groups,
    sum(error_count) as total_errors,
    round(avg(avg_latency_ms), 2) as avg_latency_with_errors
FROM minio_logs.test_results
WHERE JSON_LENGTH(error_details) > 0
GROUP BY error_details
ORDER BY frequency DESC
FORMAT JSONEachRow;

-- 20. Dynamic Threshold Analysis
SELECT 
    test_group,
    round(quantile(0.95)(success_rate), 2) as p95_success_rate,
    round(quantile(0.95)(avg_latency_ms), 2) as p95_latency,
    CASE 
        WHEN quantile(0.95)(success_rate) < 50 THEN 'Critical Performance'
        WHEN quantile(0.95)(success_rate) < 80 THEN 'Poor Performance'  
        WHEN quantile(0.95)(success_rate) < 95 THEN 'Acceptable Performance'
        ELSE 'Excellent Performance'
    END as performance_grade
FROM minio_logs.test_results
GROUP BY test_group
ORDER BY p95_success_rate DESC
FORMAT PrettyCompact;