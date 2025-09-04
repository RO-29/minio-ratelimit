#!/bin/bash

# MinIO Rate Limiting - Automation Scripts Collection
# Advanced workflow automation for testing and monitoring

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
RESULTS_DIR="./automation-results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$RESULTS_DIR/automation_report_$TIMESTAMP.md"

# Utility functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Create results directory
mkdir -p "$RESULTS_DIR"

# Function: Full System Health Check
health_check() {
    log_info "Running comprehensive system health check..."
    
    local health_report="$RESULTS_DIR/health_check_$TIMESTAMP.txt"
    
    {
        echo "# MinIO Rate Limiting System Health Check"
        echo "Generated: $(date)"
        echo "=========================================="
        echo ""
        
        echo "## Service Status"
        make status 2>&1
        echo ""
        
        echo "## Data Health"
        make query-health 2>&1
        echo ""
        
        echo "## System Overview"
        make query-overview 2>&1
        echo ""
        
        echo "## Recent Performance"
        make query-performance 2>&1
        
    } > "$health_report"
    
    log_success "Health check completed: $health_report"
}

# Function: Automated Testing Suite
run_test_suite() {
    log_info "Running automated testing suite..."
    
    local suite_dir="$RESULTS_DIR/test_suite_$TIMESTAMP"
    mkdir -p "$suite_dir"
    
    # Test 1: Quick validation
    log_info "Test 1: Quick validation (30s)"
    timeout 30s go run fast_parallel.go > "$suite_dir/quick_test.json" 2>&1 || log_warning "Quick test interrupted"
    
    # Test 2: Standard test
    log_info "Test 2: Standard comprehensive test (60s)"
    go run fast_parallel.go > "$suite_dir/standard_test.json" 2>&1
    
    # Test 3: Extended test
    log_info "Test 3: Extended test (120s)"
    timeout 120s go run fast_parallel.go > "$suite_dir/extended_test.json" 2>&1 || log_warning "Extended test interrupted"
    
    # Ingest all results
    make ingest-data >/dev/null 2>&1
    
    log_success "Test suite completed: $suite_dir"
}

# Function: Performance Analysis
analyze_performance() {
    log_info "Running performance analysis..."
    
    local analysis_report="$RESULTS_DIR/performance_analysis_$TIMESTAMP.md"
    
    {
        echo "# Performance Analysis Report"
        echo "Generated: $(date)"
        echo "============================="
        echo ""
        
        echo "## Overall System Performance"
        echo '```'
        make query-overview 2>/dev/null
        echo '```'
        echo ""
        
        echo "## Performance by Group"
        echo '```'
        make query-performance 2>/dev/null
        echo '```'
        echo ""
        
        echo "## Rate Limiting Analysis"
        echo '```'
        make query-rate-limits 2>/dev/null
        echo '```'
        echo ""
        
        echo "## Error Analysis"
        echo '```'
        make query-errors 2>/dev/null
        echo '```'
        echo ""
        
        echo "## Hourly Trends"
        echo '```'
        make query-trends 2>/dev/null
        echo '```'
        
    } > "$analysis_report"
    
    log_success "Performance analysis completed: $analysis_report"
}

# Function: Continuous Monitoring Setup
setup_continuous_monitoring() {
    log_info "Setting up continuous monitoring..."
    
    local monitor_script="$RESULTS_DIR/continuous_monitor.sh"
    
    cat > "$monitor_script" << 'EOF'
#!/bin/bash
# Continuous monitoring script - run with: nohup ./continuous_monitor.sh &

MONITOR_DIR="./continuous_monitoring"
mkdir -p "$MONITOR_DIR"

log_with_timestamp() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_with_timestamp "Starting continuous monitoring..."

while true; do
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    
    # Run test cycle
    log_with_timestamp "Running test cycle..."
    timeout 60s go run fast_parallel.go > "$MONITOR_DIR/test_$TIMESTAMP.json" 2>&1 || true
    
    # Trigger data ingestion
    make ingest-data >/dev/null 2>&1 || true
    
    # Generate mini report
    {
        echo "# Monitoring Checkpoint - $TIMESTAMP"
        echo "System Status:"
        make query-overview 2>/dev/null || echo "Query failed"
        echo ""
    } > "$MONITOR_DIR/checkpoint_$TIMESTAMP.txt"
    
    log_with_timestamp "Test cycle completed. Waiting 300 seconds..."
    sleep 300  # 5 minutes between cycles
done
EOF
    
    chmod +x "$monitor_script"
    log_success "Continuous monitoring script created: $monitor_script"
    log_info "To start monitoring: nohup $monitor_script > monitor.log 2>&1 &"
}

# Function: Load Testing
run_load_test() {
    local duration=${1:-300}  # Default 5 minutes
    log_info "Running load test for $duration seconds..."
    
    local load_dir="$RESULTS_DIR/load_test_$TIMESTAMP"
    mkdir -p "$load_dir"
    
    # Start load test
    local start_time=$(date +%s)
    timeout "${duration}s" make test-continuous > "$load_dir/load_test.log" 2>&1 || true
    local end_time=$(date +%s)
    local actual_duration=$((end_time - start_time))
    
    # Ingest results
    make ingest-data >/dev/null 2>&1
    
    # Generate load test report
    {
        echo "# Load Test Report"
        echo "Duration: $actual_duration seconds"
        echo "Started: $(date -d @$start_time)"
        echo "Ended: $(date -d @$end_time)"
        echo ""
        echo "## Results Summary"
        make query-overview 2>/dev/null || echo "Query failed"
        echo ""
        echo "## Performance Impact"
        make query-performance 2>/dev/null || echo "Query failed"
    } > "$load_dir/load_test_report.md"
    
    log_success "Load test completed: $load_dir"
}

# Function: Generate Comprehensive Report
generate_report() {
    log_info "Generating comprehensive automation report..."
    
    {
        echo "# MinIO Rate Limiting - Automation Report"
        echo "Generated: $(date)"
        echo "========================================"
        echo ""
        
        echo "## Execution Summary"
        echo "- Timestamp: $TIMESTAMP"
        echo "- Results Directory: $RESULTS_DIR"
        echo "- System: $(uname -s) $(uname -r)"
        echo ""
        
        echo "## System Health"
        if [ -f "$RESULTS_DIR/health_check_$TIMESTAMP.txt" ]; then
            echo "✅ Health check completed"
        else
            echo "❌ Health check not performed"
        fi
        echo ""
        
        echo "## Test Suite Results"
        if [ -d "$RESULTS_DIR/test_suite_$TIMESTAMP" ]; then
            echo "✅ Test suite completed"
            echo "Files generated:"
            ls -la "$RESULTS_DIR/test_suite_$TIMESTAMP/" | sed 's/^/  - /'
        else
            echo "❌ Test suite not performed"
        fi
        echo ""
        
        echo "## Performance Analysis"
        if [ -f "$RESULTS_DIR/performance_analysis_$TIMESTAMP.md" ]; then
            echo "✅ Performance analysis completed"
        else
            echo "❌ Performance analysis not performed"
        fi
        echo ""
        
        echo "## Current System Status"
        make status 2>&1 || echo "Status check failed"
        echo ""
        
        echo "## Data Summary"
        make query-health 2>&1 || echo "Data summary failed"
        echo ""
        
        echo "## Files Generated"
        echo "All results are stored in: $RESULTS_DIR"
        find "$RESULTS_DIR" -name "*$TIMESTAMP*" -type f | sed 's/^/  - /'
        echo ""
        
        echo "## Next Steps"
        echo "1. Review performance analysis: $RESULTS_DIR/performance_analysis_$TIMESTAMP.md"
        echo "2. Open dashboards: make dashboard"
        echo "3. Run custom queries: make dev-shell"
        echo "4. Export data: make export-data"
        
    } > "$REPORT_FILE"
    
    log_success "Comprehensive report generated: $REPORT_FILE"
}

# Function: Cleanup Old Results
cleanup_old_results() {
    local days=${1:-7}
    log_info "Cleaning up results older than $days days..."
    
    find "$RESULTS_DIR" -name "*" -type f -mtime +$days -delete 2>/dev/null || true
    find "$RESULTS_DIR" -name "*" -type d -empty -delete 2>/dev/null || true
    
    log_success "Cleanup completed"
}

# Function: Quick Smoke Test
smoke_test() {
    log_info "Running smoke test..."
    
    # Check if services are running
    if ! curl -s http://localhost:8123/ping >/dev/null; then
        log_error "ClickHouse not responding"
        return 1
    fi
    
    if ! curl -s http://localhost:8080/health >/dev/null; then
        log_warning "HyperDX not responding"
    fi
    
    # Run quick test
    timeout 10s go run fast_parallel.go > /tmp/smoke_test.json 2>&1 || log_warning "Smoke test interrupted"
    
    # Check if we can query data
    local record_count=$(make query-custom SQL="SELECT count() FROM minio_logs.test_results" 2>/dev/null | tail -1 | tr -d '[:space:]' || echo "0")
    
    if [ "$record_count" -gt 0 ]; then
        log_success "Smoke test passed - $record_count records in database"
    else
        log_warning "Smoke test warning - no data in database"
    fi
}

# Function: Data Export and Backup
backup_and_export() {
    log_info "Creating backup and export..."
    
    local backup_dir="$RESULTS_DIR/backup_$TIMESTAMP"
    mkdir -p "$backup_dir"
    
    # Export data
    make export-data > "$backup_dir/exported_data.json" 2>&1 || log_warning "Data export failed"
    
    # Create backup
    make backup-data > "$backup_dir/backup.log" 2>&1 || log_warning "Backup creation failed"
    
    # Export current configuration
    cp docker-compose.observability.yml "$backup_dir/" 2>/dev/null || true
    cp -r clickhouse "$backup_dir/" 2>/dev/null || true
    cp -r hyperdx "$backup_dir/" 2>/dev/null || true
    cp -r vector "$backup_dir/" 2>/dev/null || true
    
    log_success "Backup and export completed: $backup_dir"
}

# Main script logic
main() {
    local command=${1:-help}
    
    case $command in
        "health")
            health_check
            ;;
        "test-suite")
            run_test_suite
            ;;
        "performance")
            analyze_performance
            ;;
        "monitor")
            setup_continuous_monitoring
            ;;
        "load-test")
            run_load_test ${2:-300}
            ;;
        "smoke")
            smoke_test
            ;;
        "backup")
            backup_and_export
            ;;
        "cleanup")
            cleanup_old_results ${2:-7}
            ;;
        "full-automation")
            log_info "Running full automation suite..."
            smoke_test
            health_check
            run_test_suite
            analyze_performance
            backup_and_export
            generate_report
            log_success "Full automation completed! Check: $REPORT_FILE"
            ;;
        "report")
            generate_report
            ;;
        "help"|*)
            echo "MinIO Rate Limiting - Automation Scripts"
            echo "========================================"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  health              - Run system health check"
            echo "  test-suite          - Run comprehensive test suite"
            echo "  performance         - Generate performance analysis"
            echo "  monitor             - Set up continuous monitoring"
            echo "  load-test [duration]- Run load test (default 300s)"
            echo "  smoke               - Run quick smoke test"
            echo "  backup              - Create backup and export data"
            echo "  cleanup [days]      - Clean up old results (default 7 days)"
            echo "  full-automation     - Run complete automation suite"
            echo "  report              - Generate comprehensive report"
            echo "  help                - Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 full-automation  # Complete automated workflow"
            echo "  $0 load-test 600    # 10-minute load test"
            echo "  $0 cleanup 3        # Clean up files older than 3 days"
            ;;
    esac
}

# Execute main function with all arguments
main "$@"