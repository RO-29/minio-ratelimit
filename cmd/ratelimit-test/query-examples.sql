-- ClickHouse Query Examples for MinIO Rate Limiting Analysis
-- Use these queries in ClickHouse client or HyperDX for data exploration

-- ============================================================================
-- OVERVIEW QUERIES
-- ============================================================================

-- 1. Overall system health summary
SELECT
    count() as total_test_runs,
    sum(requests_sent) as total_requests,
    sum(success_count) as total_success,
    sum(rate_limited_count) as total_rate_limited,
    sum(error_count) as total_errors,
    round(sum(success_count) / sum(requests_sent) * 100, 2) as success_percentage,
    round(sum(rate_limited_count) / sum(requests_sent) * 100, 2) as rate_limit_percentage,
    round(avg(avg_latency_ms), 2) as overall_avg_latency_ms
FROM test_results
WHERE requests_sent > 0;

-- 2. Performance summary by group (using the pre-created view)
SELECT * FROM performance_by_group;

-- 3. Rate limiting analysis by API key (using the pre-created view)
SELECT * FROM rate_limit_analysis 
WHERE total_requests > 10 
ORDER BY rate_limit_percentage DESC 
LIMIT 20;

-- ============================================================================
-- TIME-BASED ANALYSIS
-- ============================================================================

-- 4. Hourly trends for the last 24 hours
SELECT * FROM hourly_metrics 
WHERE hour >= now() - INTERVAL 24 HOUR 
ORDER BY hour DESC;

-- 5. Request volume by hour and group
SELECT 
    toStartOfHour(timestamp) as hour,
    group,
    sum(requests_sent) as requests,
    sum(success_count) as success,
    sum(rate_limited_count) as rate_limited,
    round(sum(rate_limited_count) / sum(requests_sent) * 100, 2) as rate_limit_pct
FROM test_results 
WHERE timestamp >= now() - INTERVAL 24 HOUR
GROUP BY hour, group 
ORDER BY hour DESC, requests DESC;

-- 6. Peak usage identification
SELECT 
    toStartOfHour(timestamp) as peak_hour,
    sum(requests_sent) as total_requests,
    max(avg_latency_ms) as peak_latency,
    sum(rate_limited_count) as rate_limited_count
FROM test_results 
GROUP BY peak_hour 
ORDER BY total_requests DESC 
LIMIT 10;

-- ============================================================================
-- PERFORMANCE ANALYSIS
-- ============================================================================

-- 7. Latency distribution by group
SELECT 
    group,
    round(quantile(0.5)(avg_latency_ms), 2) as p50_latency_ms,
    round(quantile(0.75)(avg_latency_ms), 2) as p75_latency_ms,
    round(quantile(0.90)(avg_latency_ms), 2) as p90_latency_ms,
    round(quantile(0.95)(avg_latency_ms), 2) as p95_latency_ms,
    round(quantile(0.99)(avg_latency_ms), 2) as p99_latency_ms,
    round(max(avg_latency_ms), 2) as max_latency_ms
FROM test_results 
WHERE requests_sent > 0
GROUP BY group 
ORDER BY p95_latency_ms;

-- 8. API keys with highest latency
SELECT 
    api_key,
    group,
    count() as test_runs,
    sum(requests_sent) as total_requests,
    round(avg(avg_latency_ms), 2) as avg_latency_ms,
    round(max(avg_latency_ms), 2) as max_latency_ms
FROM test_results 
WHERE requests_sent > 0 AND api_key != ''
GROUP BY api_key, group 
HAVING total_requests > 10
ORDER BY avg_latency_ms DESC 
LIMIT 15;

-- 9. Latency vs Success Rate correlation
SELECT 
    group,
    round(avg(avg_latency_ms), 2) as avg_latency,
    round(sum(success_count) / sum(requests_sent) * 100, 2) as success_rate,
    round(sum(rate_limited_count) / sum(requests_sent) * 100, 2) as rate_limit_rate,
    sum(requests_sent) as total_requests
FROM test_results 
WHERE requests_sent > 0
GROUP BY group
ORDER BY avg_latency DESC;

-- ============================================================================
-- RATE LIMITING ANALYSIS
-- ============================================================================

-- 10. Rate limiting patterns by authentication method
SELECT 
    auth_method,
    group,
    count() as tests,
    sum(requests_sent) as requests,
    sum(rate_limited_count) as rate_limited,
    round(sum(rate_limited_count) / sum(requests_sent) * 100, 2) as rate_limit_pct
FROM test_results 
WHERE auth_method != '' AND requests_sent > 0
GROUP BY auth_method, group 
ORDER BY rate_limit_pct DESC;

-- 11. API keys hitting rate limits most frequently
SELECT 
    api_key,
    group,
    auth_method,
    sum(requests_sent) as total_requests,
    sum(rate_limited_count) as total_rate_limited,
    count() as test_runs,
    round(sum(rate_limited_count) / sum(requests_sent) * 100, 2) as rate_limit_percentage,
    round(avg(avg_latency_ms), 2) as avg_latency_ms
FROM test_results 
WHERE api_key != '' AND requests_sent > 0
GROUP BY api_key, group, auth_method
HAVING total_rate_limited > 0
ORDER BY rate_limit_percentage DESC, total_rate_limited DESC 
LIMIT 20;

-- 12. Rate limiting efficiency by group
SELECT 
    group,
    avg(limit_per_minute) as avg_limit_per_minute,
    avg(limit_per_second) as avg_limit_per_second,
    sum(rate_limited_count) as total_rate_limited,
    sum(requests_sent) as total_requests,
    round(sum(rate_limited_count) / sum(requests_sent) * 100, 2) as enforcement_rate
FROM test_results 
WHERE limit_per_minute > 0 AND requests_sent > 0
GROUP BY group 
ORDER BY enforcement_rate DESC;

-- ============================================================================
-- ERROR ANALYSIS
-- ============================================================================

-- 13. Error breakdown by type and group
SELECT 
    group,
    arrayJoin(mapKeys(error_details)) as error_type,
    sum(mapValues(error_details)) as error_count,
    count(DISTINCT api_key) as affected_api_keys
FROM test_results 
WHERE length(error_details) > 0
GROUP BY group, error_type 
ORDER BY error_count DESC;

-- 14. API keys with highest error rates
SELECT 
    api_key,
    group,
    sum(requests_sent) as total_requests,
    sum(error_count) as total_errors,
    round(sum(error_count) / sum(requests_sent) * 100, 2) as error_rate,
    round(avg(avg_latency_ms), 2) as avg_latency_ms
FROM test_results 
WHERE api_key != '' AND requests_sent > 0
GROUP BY api_key, group
HAVING total_errors > 0
ORDER BY error_rate DESC, total_errors DESC 
LIMIT 20;

-- 15. Error patterns over time
SELECT 
    toStartOfHour(timestamp) as hour,
    group,
    sum(error_count) as errors,
    sum(requests_sent) as requests,
    round(sum(error_count) / sum(requests_sent) * 100, 2) as error_rate
FROM test_results 
WHERE timestamp >= now() - INTERVAL 24 HOUR AND requests_sent > 0
GROUP BY hour, group 
HAVING errors > 0
ORDER BY hour DESC, error_rate DESC;

-- ============================================================================
-- ADVANCED ANALYTICS
-- ============================================================================

-- 16. Authentication method effectiveness
SELECT 
    auth_method,
    count(DISTINCT api_key) as unique_api_keys,
    count() as test_runs,
    sum(requests_sent) as total_requests,
    round(avg(avg_latency_ms), 2) as avg_latency,
    round(sum(success_count) / sum(requests_sent) * 100, 2) as success_rate,
    round(sum(rate_limited_count) / sum(requests_sent) * 100, 2) as rate_limit_rate
FROM test_results 
WHERE auth_method != '' AND requests_sent > 0
GROUP BY auth_method 
ORDER BY success_rate DESC;

-- 17. Group comparison matrix
SELECT 
    group1.group as group_a,
    group2.group as group_b,
    round(group1.avg_latency - group2.avg_latency, 2) as latency_diff,
    round(group1.success_rate - group2.success_rate, 2) as success_rate_diff,
    round(group1.rate_limit_rate - group2.rate_limit_rate, 2) as rate_limit_diff
FROM (
    SELECT 
        group,
        avg(avg_latency_ms) as avg_latency,
        sum(success_count) / sum(requests_sent) * 100 as success_rate,
        sum(rate_limited_count) / sum(requests_sent) * 100 as rate_limit_rate
    FROM test_results 
    WHERE requests_sent > 0 
    GROUP BY group
) group1
CROSS JOIN (
    SELECT 
        group,
        avg(avg_latency_ms) as avg_latency,
        sum(success_count) / sum(requests_sent) * 100 as success_rate,
        sum(rate_limited_count) / sum(requests_sent) * 100 as rate_limit_rate
    FROM test_results 
    WHERE requests_sent > 0 
    GROUP BY group
) group2
WHERE group1.group != group2.group
ORDER BY abs(latency_diff) DESC;

-- 18. Capacity utilization analysis
SELECT 
    group,
    avg(limit_per_minute) as configured_limit_per_minute,
    avg(current_per_minute) as avg_usage_per_minute,
    round(avg(current_per_minute) / avg(limit_per_minute) * 100, 2) as utilization_percentage,
    max(current_per_minute) as peak_usage,
    sum(rate_limited_count) as times_limit_hit
FROM test_results 
WHERE limit_per_minute > 0 AND current_per_minute > 0
GROUP BY group 
ORDER BY utilization_percentage DESC;

-- ============================================================================
-- OPERATIONAL QUERIES
-- ============================================================================

-- 19. Recent high-impact events (last hour)
SELECT 
    timestamp,
    group,
    api_key,
    requests_sent,
    rate_limited_count,
    error_count,
    avg_latency_ms,
    round(rate_limited_count / requests_sent * 100, 2) as rate_limit_pct
FROM test_results 
WHERE timestamp >= now() - INTERVAL 1 HOUR
  AND (rate_limited_count > 10 OR error_count > 5 OR avg_latency_ms > 1000)
ORDER BY timestamp DESC;

-- 20. System health check
SELECT 
    'Database Status' as metric,
    concat(toString(count()), ' test records') as value
FROM test_results
UNION ALL
SELECT 
    'Latest Data',
    toString(max(timestamp)) as value
FROM test_results
UNION ALL
SELECT 
    'Active Groups',
    toString(count(DISTINCT group)) as value
FROM test_results
WHERE timestamp >= now() - INTERVAL 24 HOUR
UNION ALL
SELECT 
    'Active API Keys',
    toString(count(DISTINCT api_key)) as value
FROM test_results
WHERE timestamp >= now() - INTERVAL 24 HOUR AND api_key != '';

-- ============================================================================
-- EXPORT QUERIES FOR DASHBOARDS
-- ============================================================================

-- For time-series charts (last 24 hours, hourly buckets)
SELECT 
    toStartOfHour(timestamp) as time,
    group,
    sum(requests_sent) as requests,
    sum(success_count) as success,
    sum(rate_limited_count) as rate_limited,
    avg(avg_latency_ms) as avg_latency
FROM test_results 
WHERE timestamp >= now() - INTERVAL 24 HOUR
GROUP BY time, group 
ORDER BY time, group
FORMAT JSONEachRow;

-- For pie charts (group distribution)
SELECT 
    group,
    sum(requests_sent) as requests
FROM test_results 
WHERE timestamp >= now() - INTERVAL 24 HOUR
GROUP BY group 
ORDER BY requests DESC
FORMAT JSONEachRow;