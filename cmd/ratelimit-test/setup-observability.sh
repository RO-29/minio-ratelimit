#!/bin/bash

# MinIO Rate Limiting Observability Setup Script
# Sets up ClickHouse 25.8 + HyperDX + Vector for comprehensive log analysis

set -e

echo "🚀 Setting up MinIO Rate Limiting Observability Stack"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check dependencies
check_dependencies() {
    print_info "Checking dependencies..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    print_status "All dependencies are available"
}

# Create necessary directories
setup_directories() {
    print_info "Setting up directories..."
    
    mkdir -p clickhouse hyperdx vector logs
    chmod 755 clickhouse hyperdx vector logs
    
    print_status "Directories created successfully"
}

# Start the observability stack
start_services() {
    print_info "Starting observability services..."
    
    # Stop any existing services
    docker-compose -f docker-compose.observability.yml down --remove-orphans 2>/dev/null || true
    
    # Start services
    docker-compose -f docker-compose.observability.yml up -d
    
    print_status "Services started successfully"
}

# Wait for services to be ready
wait_for_services() {
    print_info "Waiting for services to be ready..."
    
    # Wait for ClickHouse
    print_info "Waiting for ClickHouse..."
    timeout=60
    counter=0
    while ! docker-compose -f docker-compose.observability.yml exec clickhouse wget -q --spider http://localhost:8123/ping 2>/dev/null; do
        counter=$((counter + 1))
        if [ $counter -eq $timeout ]; then
            print_error "ClickHouse failed to start within $timeout seconds"
            exit 1
        fi
        sleep 1
    done
    print_status "ClickHouse is ready"
    
    # Wait for HyperDX
    print_info "Waiting for HyperDX..."
    counter=0
    while ! curl -sf http://localhost:8080/health >/dev/null 2>&1; do
        counter=$((counter + 1))
        if [ $counter -eq $timeout ]; then
            print_warning "HyperDX may not be fully ready, but continuing..."
            break
        fi
        sleep 2
    done
    print_status "HyperDX is ready"
    
    print_status "All services are ready"
}

# Ingest comprehensive_results.json
ingest_data() {
    print_info "Ingesting comprehensive_results.json data..."
    
    if [ ! -f "comprehensive_results.json" ]; then
        print_warning "comprehensive_results.json not found. Run your tests first to generate data."
        return 0
    fi
    
    # Vector should automatically pick up the file, but let's trigger a restart to ensure processing
    docker-compose -f docker-compose.observability.yml restart vector
    
    # Give Vector some time to process the file
    sleep 5
    
    print_status "Data ingestion initiated"
}

# Verify data ingestion
verify_data() {
    print_info "Verifying data ingestion..."
    
    # Check if data exists in ClickHouse
    count=$(docker-compose -f docker-compose.observability.yml exec -T clickhouse clickhouse-client --query "SELECT count() FROM minio_logs.test_results" 2>/dev/null || echo "0")
    
    if [ "$count" -gt "0" ]; then
        print_status "Data verification successful: $count records found in ClickHouse"
        
        # Show sample data
        print_info "Sample data preview:"
        docker-compose -f docker-compose.observability.yml exec -T clickhouse clickhouse-client --query "SELECT group, sum(requests_sent) as requests, sum(success_count) as success, sum(rate_limited_count) as rate_limited FROM minio_logs.test_results GROUP BY group ORDER BY requests DESC" --format=PrettyCompact
    else
        print_warning "No data found in ClickHouse yet. Data may still be processing."
    fi
}

# Show connection information
show_connection_info() {
    echo ""
    echo "🎉 Observability Stack Setup Complete!"
    echo "======================================"
    echo ""
    echo "📊 Access Points:"
    echo "  ClickHouse HTTP:  http://localhost:8123"
    echo "  ClickHouse TCP:   localhost:9000"
    echo "  HyperDX Web UI:   http://localhost:8080"
    echo "  Vector API:       http://localhost:8686"
    echo ""
    echo "🔍 Useful ClickHouse Queries:"
    echo "  # Overall stats:"
    echo "  SELECT * FROM minio_logs.rate_limit_analysis;"
    echo ""
    echo "  # Performance by group:"
    echo "  SELECT * FROM minio_logs.performance_by_group;"
    echo ""
    echo "  # Hourly trends:"
    echo "  SELECT * FROM minio_logs.hourly_metrics ORDER BY hour DESC LIMIT 24;"
    echo ""
    echo "  # Error analysis:"
    echo "  SELECT group, arrayJoin(mapKeys(error_details)) as error_type, sum(mapValues(error_details)) as count"
    echo "  FROM minio_logs.test_results WHERE length(error_details) > 0"
    echo "  GROUP BY group, error_type ORDER BY count DESC;"
    echo ""
    echo "📈 Next Steps:"
    echo "  1. Access HyperDX at http://localhost:8080 for interactive dashboards"
    echo "  2. Run your MinIO rate limiting tests to generate more data"
    echo "  3. Use the ClickHouse queries above for custom analysis"
    echo "  4. Check Vector logs: docker-compose -f docker-compose.observability.yml logs vector"
    echo ""
}

# Main execution
main() {
    check_dependencies
    setup_directories
    start_services
    wait_for_services
    ingest_data
    verify_data
    show_connection_info
}

# Handle script interruption
trap 'print_error "Setup interrupted"; exit 1' INT TERM

# Run main function
main "$@"