# MinIO Rate Limiting with HAProxy - Management Makefile
#
# Common commands:
#   make up          - Start all services
#   make down        - Stop all services
#   make restart     - Restart all services
#   make reload      - Reload HAProxy without downtime
#   make logs        - View logs from all services
#   make status      - Check service status
#   make clean       - Clean up Docker resources
#
# HAProxy specific:
#   make reload-haproxy   - Reload only HAProxy configs
#   make haproxy-stats    - Open HAProxy stats in browser
#   make test-limits      - Run a simple rate limit test
#
# Configuration management:
#   make backup-configs   - Backup all configuration files
#   make increase-limits  - Increase premium rate limits
#
# Advanced testing scenarios:
#   make test-basic       - Test only basic tier accounts
#   make test-standard    - Test only standard tier accounts
#   make test-premium     - Test only premium tier accounts
#   make test-stress      - Run a premium stress test
#   make test-quick       - Run a quick test (15s duration)
#   make test-extended    - Run an extended test (5m duration)
#   make test-export      - Run test and export detailed JSON results

.PHONY: up down restart reload logs status clean reload-haproxy haproxy-stats test-limits backup-configs increase-limits update-maps help test-basic test-standard test-premium test-stress test-quick test-extended test-export test-all-tiers test-custom compare-results ensure-results-dir lint lint-go lint-haproxy lint-lua test-haproxy test-lua validate-all ci-test ci-validate ci-setup

# Default target
help:
	@echo "MinIO Rate Limiting with HAProxy - Management Commands"
	@echo ""
	@echo "Usage:"
	@echo "  make up                - Start all services"
	@echo "  make down              - Stop all services"
	@echo "  make restart           - Restart all services"
	@echo "  make reload            - Reload HAProxy without downtime"
	@echo "  make logs              - View logs from all services"
	@echo "  make status            - Check service status"
	@echo "  make clean             - Clean up Docker resources"
	@echo ""
	@echo "HAProxy specific:"
	@echo "  make reload-haproxy    - Reload only HAProxy configs"
	@echo "  make haproxy-stats     - Open HAProxy stats in browser"
	@echo "  make test-limits       - Run a simple rate limit test"
	@echo ""
	@echo "Configuration management:"
	@echo "  make backup-configs    - Backup all configuration files"
	@echo "  make increase-limits   - Increase premium rate limits"
	@echo "  make update-maps       - Update HAProxy map files only"
	@echo ""
	@echo "Advanced testing scenarios:"
	@echo "  make test-basic        - Test only basic tier accounts"
	@echo "  make test-standard     - Test only standard tier accounts"
	@echo "  make test-premium      - Test only premium tier accounts"
	@echo "  make test-stress       - Run a premium stress test"
	@echo "  make test-quick        - Run a quick test (15s duration)"
	@echo "  make test-extended     - Run an extended test (5m duration)"
	@echo "  make test-export       - Run test and export detailed JSON results"
	@echo "  make test-all-tiers    - Run tests across all tiers with analysis"
	@echo "  make test-custom       - Run test with custom configuration"
	@echo "  make compare-results   - Compare results between different test runs"
	@echo ""
	@echo "Linting and validation:"
	@echo "  make lint              - Run all linting checks"
	@echo "  make lint-go           - Lint Go code"
	@echo "  make lint-haproxy      - Check HAProxy configuration syntax"
	@echo "  make lint-lua          - Check Lua scripts syntax"
	@echo "  make test-haproxy      - Test HAProxy configuration"
	@echo "  make test-lua          - Test Lua scripts"
	@echo "  make validate-all      - Run all validation checks"
	@echo "  make ci-test           - Run tests for CI environment"
	@echo "  make ci-validate       - Run validations for CI environment"

# Start all services
up:
	@echo "Starting all services..."
	@docker-compose up -d
	@echo "Services started. HAProxy endpoints:"
	@echo "  - Main: http://localhost:80"
	@echo "  - Stats: http://localhost:8404/stats"
	@echo "  - MinIO Console: http://localhost:9091"

# Stop all services
down:
	@echo "Stopping all services..."
	@docker-compose down
	@echo "Services stopped"

# Restart all services
restart:
	@echo "Restarting all services..."
	@docker-compose restart
	@echo "Services restarted"

# Reload HAProxy without stopping containers
reload: reload-haproxy

# View logs
logs:
	@docker-compose logs -f

# Check status
status:
	@docker-compose ps

# Clean up
clean:
	@echo "Cleaning up Docker resources..."
	@docker-compose down -v --remove-orphans
	@echo "Resources cleaned"

# Reload HAProxy configuration
reload-haproxy:
	@echo "Reloading HAProxy configuration without downtime..."
	@echo "Reloading HAProxy 1..."
	@docker-compose exec haproxy1 kill -SIGUSR2 1
	@sleep 2
	@echo "Reloading HAProxy 2..."
	@docker-compose exec haproxy2 kill -SIGUSR2 1
	@echo "HAProxy configuration reloaded"

# Open HAProxy stats in browser
haproxy-stats:
	@echo "Opening HAProxy stats in browser..."
	@open http://localhost:8404/stats

# Test rate limits with curl
test-limits:
	@echo "Testing rate limits with curl..."
	@echo "Running 5 consecutive requests to test rate limiting..."
	@curl -v -H "Authorization: AWS4-HMAC-SHA256 Credential=5HQZO7EDOM4XBNO642GQ/20250904/us-east-1/s3/aws4_request" http://localhost/
	@echo "\n\nChecking response with verbose output to see all headers..."
	@curl -v -H "Authorization: AWS4-HMAC-SHA256 Credential=5HQZO7EDOM4XBNO642GQ/20250904/us-east-1/s3/aws4_request" http://localhost/

# Backup all configuration files
backup-configs:
	@echo "Backing up configuration files..."
	@mkdir -p ./backups/$(shell date +%Y%m%d_%H%M%S)
	@cp ./haproxy.cfg ./backups/$(shell date +%Y%m%d_%H%M%S)/
	@cp ./extract_api_keys.lua ./backups/$(shell date +%Y%m%d_%H%M%S)/
	@cp ./dynamic_rate_limiter.lua ./backups/$(shell date +%Y%m%d_%H%M%S)/
	@cp -r ./config ./backups/$(shell date +%Y%m%d_%H%M%S)/
	@echo "Backup created in ./backups/$(shell date +%Y%m%d_%H%M%S)/"

# Increase premium rate limits
increase-limits:
	@echo "Increasing premium rate limits..."
	@sed -i '' 's/premium [0-9]*/premium 10000/' ./config/rate_limits_per_minute.map
	@sed -i '' 's/premium [0-9]*/premium 200/' ./config/rate_limits_per_second.map
	@echo "Rate limits increased. Remember to reload HAProxy with 'make reload'"

# Update HAProxy map files
update-maps:
	@echo "Updating HAProxy map files..."
	@for container in haproxy1 haproxy2; do \
		docker-compose exec $$container sh -c "cat /usr/local/etc/haproxy/config/rate_limits_per_minute.map | sed 's/\r//' > /tmp/rate_limits_per_minute.map && mv /tmp/rate_limits_per_minute.map /usr/local/etc/haproxy/config/rate_limits_per_minute.map"; \
		docker-compose exec $$container sh -c "cat /usr/local/etc/haproxy/config/rate_limits_per_second.map | sed 's/\r//' > /tmp/rate_limits_per_second.map && mv /tmp/rate_limits_per_second.map /usr/local/etc/haproxy/config/rate_limits_per_second.map"; \
		docker-compose exec $$container sh -c "cat /usr/local/etc/haproxy/config/api_key_groups.map | sed 's/\r//' > /tmp/api_key_groups.map && mv /tmp/api_key_groups.map /usr/local/etc/haproxy/config/api_key_groups.map"; \
	done
	@echo "Map files updated. Remember to reload HAProxy with 'make reload'"

#
# Advanced Rate Limit Testing Scenarios
#

# Define variables for test commands
TEST_CMD = cd ./cmd/ratelimit-test && ./build/minio-ratelimit-test
TEST_RESULTS_DIR = ./cmd/ratelimit-test/results

# Include linting and validation targets
include linting_targets.mk

# Ensure results directory exists
ensure-results-dir:
	@mkdir -p $(TEST_RESULTS_DIR)

# Test only basic tier accounts
test-basic: ensure-results-dir
	@echo "🧪 Running tests for BASIC tier accounts only..."
	@cd ./cmd/ratelimit-test && go build -o build/minio-ratelimit-test *.go
	@$(TEST_CMD) -tiers=basic -duration=60s -accounts=5 > $(TEST_RESULTS_DIR)/basic_results.json
	@echo "✅ Basic tier testing complete!"
	@echo "📊 Results saved to $(TEST_RESULTS_DIR)/basic_results.json"

# Test only standard tier accounts
test-standard: ensure-results-dir
	@echo "🧪 Running tests for STANDARD tier accounts only..."
	@cd ./cmd/ratelimit-test && go build -o build/minio-ratelimit-test *.go
	@$(TEST_CMD) -tiers=standard -duration=60s -accounts=5 > $(TEST_RESULTS_DIR)/standard_results.json
	@echo "✅ Standard tier testing complete!"
	@echo "📊 Results saved to $(TEST_RESULTS_DIR)/standard_results.json"

# Test only premium tier accounts
test-premium: ensure-results-dir
	@echo "🧪 Running tests for PREMIUM tier accounts only..."
	@cd ./cmd/ratelimit-test && go build -o build/minio-ratelimit-test *.go
	@$(TEST_CMD) -tiers=premium -duration=60s -accounts=5 > $(TEST_RESULTS_DIR)/premium_results.json
	@echo "✅ Premium tier testing complete!"
	@echo "📊 Results saved to $(TEST_RESULTS_DIR)/premium_results.json"

# Run a premium stress test
test-stress: ensure-results-dir
	@echo "💪 Running PREMIUM STRESS test to find actual limits..."
	@cd ./cmd/ratelimit-test && go build -o build/minio-ratelimit-test *.go
	@$(TEST_CMD) -stress-premium -duration=120s -accounts=5 > $(TEST_RESULTS_DIR)/stress_results.json
	@echo "✅ Premium stress testing complete!"
	@echo "📊 Results saved to $(TEST_RESULTS_DIR)/stress_results.json"

# Run a quick test (15s duration)
test-quick: ensure-results-dir
	@echo "🚀 Running QUICK test (15s duration)..."
	@cd ./cmd/ratelimit-test && go build -o build/minio-ratelimit-test *.go
	@$(TEST_CMD) -duration=15s -accounts=2 > $(TEST_RESULTS_DIR)/quick_results.json
	@echo "✅ Quick testing complete!"
	@echo "📊 Results saved to $(TEST_RESULTS_DIR)/quick_results.json"

# Run an extended test (5m duration)
test-extended: ensure-results-dir
	@echo "⏰ Running EXTENDED test (5m duration)..."
	@cd ./cmd/ratelimit-test && go build -o build/minio-ratelimit-test *.go
	@$(TEST_CMD) -duration=5m -accounts=3 > $(TEST_RESULTS_DIR)/extended_results.json
	@echo "✅ Extended testing complete!"
	@echo "📊 Results saved to $(TEST_RESULTS_DIR)/extended_results.json"

# Run test and export detailed JSON results
test-export: ensure-results-dir
	@echo "📊 Running test with DETAILED JSON export..."
	@cd ./cmd/ratelimit-test && go build -o build/minio-ratelimit-test *.go
	@$(TEST_CMD) -duration=60s -accounts=3 -json -output=$(TEST_RESULTS_DIR)/detailed_export.json > $(TEST_RESULTS_DIR)/test_output.log
	@echo "✅ Testing with JSON export complete!"
	@echo "📊 Results saved to $(TEST_RESULTS_DIR)/detailed_export.json"

# Run tests across all tiers with comprehensive analysis
test-all-tiers: ensure-results-dir
	@echo "🔬 Running COMPREHENSIVE tests across ALL TIERS..."
	@cd ./cmd/ratelimit-test && go build -o build/minio-ratelimit-test *.go
	@$(TEST_CMD) -duration=90s -accounts=3 -tiers=basic,standard,premium -json -output=$(TEST_RESULTS_DIR)/all_tiers_results.json > $(TEST_RESULTS_DIR)/all_tiers_output.log
	@echo "✅ All-tier comprehensive testing complete!"
	@echo "📊 Results saved to $(TEST_RESULTS_DIR)/all_tiers_results.json"

# Test with custom configuration
test-custom: ensure-results-dir
	@echo "🔧 Running CUSTOM configuration test..."
	@read -p "Duration (e.g. 30s, 1m, 5m): " duration; \
	read -p "Accounts per tier (e.g. 1-10): " accounts; \
	read -p "Tiers to test (basic,standard,premium): " tiers; \
	read -p "Export JSON? (y/n): " export_json; \
	export_option=""; \
	if [ "$$export_json" = "y" ]; then \
		export_option="-json -output=$(TEST_RESULTS_DIR)/custom_results.json"; \
	fi; \
	cd ./cmd/ratelimit-test && go build -o build/minio-ratelimit-test *.go; \
	./build/minio-ratelimit-test -duration=$$duration -accounts=$$accounts -tiers=$$tiers $$export_option > $(TEST_RESULTS_DIR)/custom_output.log
	@echo "✅ Custom testing complete!"
	@echo "📊 Results saved to $(TEST_RESULTS_DIR)/custom_output.log"

# Compare test results between different runs
compare-results:
	@echo "📈 Comparing test results..."
	@read -p "First results file: " file1; \
	read -p "Second results file: " file2; \
	echo "Comparing $${file1} with $${file2}..."; \
	cd ./cmd/ratelimit-test && go run ./scripts/compare_results.go -file1=$(TEST_RESULTS_DIR)/$$file1 -file2=$(TEST_RESULTS_DIR)/$$file2
	@echo "✅ Comparison complete!"
