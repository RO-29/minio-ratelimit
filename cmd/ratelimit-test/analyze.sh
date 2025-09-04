#!/bin/bash

# Quick Analysis Commands for MinIO Rate Limiting Data
# Usage: ./analyze.sh [command]

CLICKHOUSE_URL="http://localhost:8123/"

# Colors for output
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
NC='\033[0m'

print_header() {
    echo -e "${CYAN}$1${NC}"
    echo "$(echo "$1" | sed 's/./=/g')"
}

# Function to run ClickHouse query
query() {
    curl -s "$CLICKHOUSE_URL" -d "$1"
}

case ${1:-overview} in
    "overview"|"")
        print_header "📊 SYSTEM OVERVIEW"
        query "SELECT 
            'Total Requests' as metric, 
            toString(sum(requests_sent)) as value 
        FROM minio_logs.test_results
        UNION ALL
        SELECT 
            'Total Success', 
            toString(sum(success_count))
        FROM minio_logs.test_results
        UNION ALL
        SELECT 
            'Total Rate Limited', 
            toString(sum(rate_limited_count))
        FROM minio_logs.test_results
        UNION ALL
        SELECT 
            'Success Rate %', 
            toString(round(sum(success_count)/sum(requests_sent)*100, 2))
        FROM minio_logs.test_results
        FORMAT PrettyCompact"
        ;;
        
    "groups")
        print_header "📈 PERFORMANCE BY GROUP"
        query "SELECT 
            \`group\`,
            requests_sent,
            success_count,
            rate_limited_count,
            round(success_count/requests_sent*100, 2) as success_rate_pct,
            round(rate_limited_count/requests_sent*100, 2) as rate_limit_pct,
            round(avg_latency_ms, 2) as avg_latency
        FROM minio_logs.test_results 
        ORDER BY requests_sent DESC
        FORMAT PrettyCompact"
        ;;
        
    "latency")
        print_header "⚡ LATENCY ANALYSIS"
        query "SELECT 
            \`group\`,
            round(avg_latency_ms, 2) as avg_latency_ms,
            CASE 
                WHEN avg_latency_ms < 100 THEN 'Excellent'
                WHEN avg_latency_ms < 500 THEN 'Good' 
                WHEN avg_latency_ms < 1000 THEN 'Fair'
                ELSE 'Poor'
            END as performance_rating
        FROM minio_logs.test_results 
        ORDER BY avg_latency_ms
        FORMAT PrettyCompact"
        ;;
        
    "rate-limits")
        print_header "🚦 RATE LIMITING EFFECTIVENESS"
        query "SELECT 
            \`group\`,
            requests_sent,
            rate_limited_count,
            round(rate_limited_count/requests_sent*100, 2) as rate_limit_percentage,
            CASE 
                WHEN rate_limited_count = 0 THEN 'No Limits Hit'
                WHEN rate_limited_count/requests_sent < 0.1 THEN 'Low Rate Limiting'
                WHEN rate_limited_count/requests_sent < 0.5 THEN 'Moderate Rate Limiting'
                ELSE 'High Rate Limiting'
            END as rate_limit_level
        FROM minio_logs.test_results 
        ORDER BY rate_limit_percentage DESC
        FORMAT PrettyCompact"
        ;;
        
    "efficiency")
        print_header "🎯 SYSTEM EFFICIENCY"
        query "SELECT 
            \`group\`,
            requests_sent as total_requests,
            success_count as successful,
            rate_limited_count as rate_limited,
            error_count as errors,
            round(success_count/requests_sent*100, 2) as success_rate,
            round((requests_sent - rate_limited_count - error_count)/requests_sent*100, 2) as efficiency_rate
        FROM minio_logs.test_results 
        ORDER BY efficiency_rate DESC
        FORMAT PrettyCompact"
        ;;
        
    "summary")
        print_header "📋 EXECUTIVE SUMMARY"
        query "WITH stats AS (
            SELECT 
                sum(requests_sent) as total_requests,
                sum(success_count) as total_success,
                sum(rate_limited_count) as total_rate_limited,
                sum(error_count) as total_errors,
                avg(avg_latency_ms) as overall_avg_latency
            FROM minio_logs.test_results
        )
        SELECT 
            'Total Test Requests' as metric,
            toString(total_requests) as value
        FROM stats
        UNION ALL
        SELECT 
            'Overall Success Rate',
            concat(toString(round(total_success/total_requests*100, 2)), '%')
        FROM stats
        UNION ALL
        SELECT 
            'Rate Limiting Impact',
            concat(toString(round(total_rate_limited/total_requests*100, 2)), '%')
        FROM stats
        UNION ALL
        SELECT 
            'Average Latency',
            concat(toString(round(overall_avg_latency, 2)), 'ms')
        FROM stats
        FORMAT PrettyCompact"
        ;;
        
    "raw")
        print_header "🗄️  RAW DATA"
        query "SELECT * FROM minio_logs.test_results ORDER BY timestamp DESC FORMAT PrettyCompact"
        ;;
        
    "help")
        echo -e "${CYAN}MinIO Rate Limiting Analysis Tool${NC}"
        echo "================================="
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  overview     - System overview (default)"
        echo "  groups       - Performance by group"
        echo "  latency      - Latency analysis"
        echo "  rate-limits  - Rate limiting effectiveness"
        echo "  efficiency   - System efficiency metrics"
        echo "  summary      - Executive summary"
        echo "  raw          - Show raw data"
        echo "  help         - Show this help"
        echo ""
        echo "Examples:"
        echo "  $0 overview"
        echo "  $0 groups"
        echo "  $0 latency"
        ;;
        
    *)
        echo -e "${YELLOW}❓ Unknown command: $1${NC}"
        echo "Run '$0 help' for available commands"
        exit 1
        ;;
esac

echo ""