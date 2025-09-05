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
# CI/CD specific:
#   make ci-setup         - Setup CI environment
#   make ci-test          - Run tests for CI
#   make ci-validate      - Run validations for CI
#
# Advanced testing scenarios:
#   make test-basic       - Test only basic tier accounts
#   make test-standard    - Test only standard tier accounts
#   make test-premium     - Test only premium tier accounts
#   make test-stress      - Run a premium stress test
#   make test-quick       - Run a quick test (15s duration)
#   make test-extended    - Run an extended test (5m duration)
#   make test-export      - Run test and export detailed JSON results
#
# Project management:
#   make cleanup          - Clean up and organize project files into .bin directory
#   make clean            - Clean up Docker resources
#   make versions         - Show current versions used in the project

# Include centralized version control
include versions.mk

.PHONY: up down restart reload logs status clean reload-haproxy haproxy-stats test-limits backup-configs increase-limits update-maps help test-basic test-standard test-premium test-stress test-quick test-extended test-export test-all-tiers test-custom compare-results ensure-results-dir lint lint-go lint-haproxy lint-lua test-haproxy test-lua validate-all ci-test ci-validate ci-setup cleanup versions update-go-version update-haproxy-version update-versions check-versions verify-versions update-all-versions

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
	@echo ""
	@echo "CI/CD specific commands:"
	@echo "  make ci-setup          - Setup CI environment (generates service accounts, detects Docker Compose)"
	@echo "  make ci-test           - Run tests for CI environment with proper path resolution"
	@echo "  make ci-validate       - Run validations for CI environment with appropriate formatting"
	@echo ""
	@echo "Project management:"
	@echo "  make cleanup                - Clean up and organize project files into .bin directory"
	@echo "  make versions               - Show current versions used in the project"
	@echo "  make update-go-version      - Update Go version in all go.mod files"
	@echo "  make update-haproxy-version - Update HAProxy version in all files"
	@echo "  make update-versions        - Update all versions throughout the project"
	@echo "  make update-all-versions    - Update all versions and run verification"
	@echo "  make verify-versions        - Verify version consistency across the project"
	@echo "  make check-versions         - Check if environment meets version requirements"
	@echo ""
	@echo "Rate limiting specific:"
	@echo "  make validate-ratelimit - Validate complete rate limiting setup"
	@echo "  make ratelimit-test     - Run rate limiting tests"
	@echo "  make ratelimit-tokens   - Generate test tokens for rate limiting"

# Docker Compose commands are now defined in docker_compose_targets.mk

# Reload HAProxy without stopping containers
reload: reload-haproxy

# Docker Compose commands are now defined in docker_compose_targets.mk

# Reload HAProxy configuration
reload-haproxy: docker-compose-info
	@echo "Reloading HAProxy configuration without downtime..."
	@echo "Reloading HAProxy 1..."
	@$(DOCKER_COMPOSE_CMD) exec haproxy1 kill -SIGUSR2 1
	@sleep 2
	@echo "Reloading HAProxy 2..."
	@$(DOCKER_COMPOSE_CMD) exec haproxy2 kill -SIGUSR2 1
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
	@cp ./haproxy/haproxy.cfg ./backups/$(shell date +%Y%m%d_%H%M%S)/
	@cp ./haproxy/lua/extract_api_keys.lua ./backups/$(shell date +%Y%m%d_%H%M%S)/
	@cp ./haproxy/lua/dynamic_rate_limiter.lua ./backups/$(shell date +%Y%m%d_%H%M%S)/
	@cp -r ./haproxy/config ./backups/$(shell date +%Y%m%d_%H%M%S)/
	@echo "Backup created in ./backups/$(shell date +%Y%m%d_%H%M%S)/"

# Increase premium rate limits
increase-limits:
	@echo "Increasing premium rate limits..."
	@sed -i '' 's/premium [0-9]*/premium 10000/' ./haproxy/config/rate_limits_per_minute.map
	@sed -i '' 's/premium [0-9]*/premium 200/' ./haproxy/config/rate_limits_per_second.map
	@echo "Rate limits increased. Remember to reload HAProxy with 'make reload'"

# Update HAProxy map files
update-maps: docker-compose-info
	@echo "Updating HAProxy map files..."
	@for container in haproxy1 haproxy2; do \
		$(DOCKER_COMPOSE_CMD) exec $$container sh -c "cat /usr/local/etc/haproxy/config/rate_limits_per_minute.map | sed 's/\r//' > /tmp/rate_limits_per_minute.map && mv /tmp/rate_limits_per_minute.map /usr/local/etc/haproxy/config/rate_limits_per_minute.map"; \
		$(DOCKER_COMPOSE_CMD) exec $$container sh -c "cat /usr/local/etc/haproxy/config/rate_limits_per_second.map | sed 's/\r//' > /tmp/rate_limits_per_second.map && mv /tmp/rate_limits_per_second.map /usr/local/etc/haproxy/config/rate_limits_per_second.map"; \
		$(DOCKER_COMPOSE_CMD) exec $$container sh -c "cat /usr/local/etc/haproxy/config/api_key_groups.map | sed 's/\r//' > /tmp/api_key_groups.map && mv /tmp/api_key_groups.map /usr/local/etc/haproxy/config/api_key_groups.map"; \
	done
	@echo "Map files updated. Remember to reload HAProxy with 'make reload'"

#
# Advanced Rate Limit Testing Scenarios
#

# Define variables for test commands
TEST_CMD = cd ./cmd/ratelimit-test && ./build/minio-ratelimit-test -config=../../haproxy/config/generated_service_accounts.json
TEST_RESULTS_DIR = ./test-results

# Include linting, validation, rate limiting, and Docker Compose targets
include linting_targets.mk
include ratelimit_targets.mk
include docker_compose_targets.mk

# Ensure results directory exists
ensure-results-dir:
	@mkdir -p $(TEST_RESULTS_DIR)

# Test only basic tier accounts
test-basic: ensure-results-dir
	@echo "🧪 Running tests for BASIC tier accounts only..."
	@cd ./cmd/ratelimit-test && go build -o build/minio-ratelimit-test *.go
	@cd ./cmd/ratelimit-test && ./build/minio-ratelimit-test -config=../../haproxy/config/generated_service_accounts.json -tiers=basic -duration=60s -accounts=5 > ../../test-results/basic_results.json
	@echo "✅ Basic tier testing complete!"
	@echo "📊 Results saved to $(TEST_RESULTS_DIR)/basic_results.json"

# Test only standard tier accounts
test-standard: ensure-results-dir
	@echo "🧪 Running tests for STANDARD tier accounts only..."
	@cd ./cmd/ratelimit-test && go build -o build/minio-ratelimit-test *.go
	@cd ./cmd/ratelimit-test && ./build/minio-ratelimit-test -config=../../haproxy/config/generated_service_accounts.json -tiers=standard -duration=60s -accounts=5 > ../../test-results/standard_results.json
	@echo "✅ Standard tier testing complete!"
	@echo "📊 Results saved to $(TEST_RESULTS_DIR)/standard_results.json"

# Test only premium tier accounts
test-premium: ensure-results-dir
	@echo "🧪 Running tests for PREMIUM tier accounts only..."
	@cd ./cmd/ratelimit-test && go build -o build/minio-ratelimit-test *.go
	@cd ./cmd/ratelimit-test && ./build/minio-ratelimit-test -config=../../haproxy/config/generated_service_accounts.json -tiers=premium -duration=60s -accounts=5 > ../../test-results/premium_results.json
	@echo "✅ Premium tier testing complete!"
	@echo "📊 Results saved to $(TEST_RESULTS_DIR)/premium_results.json"

# Run a premium stress test
test-stress: ensure-results-dir
	@echo "💪 Running PREMIUM STRESS test to find actual limits..."
	@cd ./cmd/ratelimit-test && go build -o build/minio-ratelimit-test *.go
	@cd ./cmd/ratelimit-test && ./build/minio-ratelimit-test -config=../../haproxy/config/generated_service_accounts.json -stress-premium -duration=120s -accounts=5 > ../../test-results/stress_results.json
	@echo "✅ Premium stress testing complete!"
	@echo "📊 Results saved to $(TEST_RESULTS_DIR)/stress_results.json"

# Run a quick test (15s duration)
test-quick: ensure-results-dir
	@echo "🚀 Running QUICK test (15s duration)..."
	@cd ./cmd/ratelimit-test && go build -o build/minio-ratelimit-test *.go
	@cd ./cmd/ratelimit-test && ./build/minio-ratelimit-test -config=../../haproxy/config/generated_service_accounts.json -duration=15s -accounts=2 > ../../test-results/quick_results.json
	@echo "✅ Quick testing complete!"
	@echo "📊 Results saved to $(TEST_RESULTS_DIR)/quick_results.json"

# Run an extended test (5m duration)
test-extended: ensure-results-dir
	@echo "⏰ Running EXTENDED test (5m duration)..."
	@cd ./cmd/ratelimit-test && go build -o build/minio-ratelimit-test *.go
	@cd ./cmd/ratelimit-test && ./build/minio-ratelimit-test -config=../../haproxy/config/generated_service_accounts.json -duration=5m -accounts=3 > ../../test-results/extended_results.json
	@echo "✅ Extended testing complete!"
	@echo "📊 Results saved to $(TEST_RESULTS_DIR)/extended_results.json"

# Run test and export detailed JSON results
test-export: ensure-results-dir
	@echo "📊 Running test with DETAILED JSON export..."
	@cd ./cmd/ratelimit-test && go build -o build/minio-ratelimit-test *.go
	@cd ./cmd/ratelimit-test && ./build/minio-ratelimit-test -config=../../haproxy/config/generated_service_accounts.json -duration=60s -accounts=3 -json -output=../../test-results/detailed_export.json > ../../test-results/test_output.log
	@echo "✅ Testing with JSON export complete!"
	@echo "📊 Results saved to $(TEST_RESULTS_DIR)/detailed_export.json"

# Run tests across all tiers with comprehensive analysis
test-all-tiers: ensure-results-dir
	@echo "🔬 Running COMPREHENSIVE tests across ALL TIERS..."
	@cd ./cmd/ratelimit-test && go build -o build/minio-ratelimit-test *.go
	@cd ./cmd/ratelimit-test && ./build/minio-ratelimit-test -config=../../haproxy/config/generated_service_accounts.json -duration=90s -accounts=3 -tiers=basic,standard,premium -json -output=../../test-results/all_tiers_results.json > ../../test-results/all_tiers_output.log
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
		export_option="-json -output=../../test-results/custom_results.json"; \
	fi; \
	cd ./cmd/ratelimit-test && go build -o build/minio-ratelimit-test *.go; \
	./build/minio-ratelimit-test -config=../../haproxy/config/generated_service_accounts.json -duration=$$duration -accounts=$$accounts -tiers=$$tiers $$export_option > ../../test-results/custom_output.log
	@echo "✅ Custom testing complete!"
	@echo "📊 Results saved to $(TEST_RESULTS_DIR)/custom_output.log"

# Compare test results between different runs
compare-results:
	@echo "📈 Comparing test results..."
	@read -p "First results file: " file1; \
	read -p "Second results file: " file2; \
	echo "Comparing $${file1} with $${file2}..."; \
	cd ./cmd/ratelimit-test && go run ./scripts/compare_results.go -file1=../../test-results/$$file1 -file2=../../test-results/$$file2
	@echo "✅ Comparison complete!"

# Clean up and organize project files
cleanup:
	@echo "🧹 Cleaning up project files..."
	@./scripts/cleanup.sh
	@echo "✅ Project cleanup complete!"

# Display version information
versions:
	@echo "🔢 Project Version Information"
	@echo "=============================="
	@echo "Go version:              $(GO_VERSION) (toolchain $(GO_TOOLCHAIN_VERSION))"
	@echo "Lua version:             $(LUA_VERSION)"
	@echo "HAProxy version:         $(HAPROXY_VERSION)"
	@echo "Docker Compose version:  $(DOCKER_COMPOSE_VERSION)"
	@echo "MinIO version:           $(MINIO_VERSION)"
	@echo ""
	@echo "Installed Versions:"
	@if command -v go >/dev/null 2>&1; then echo "Go:            $$(go version | awk '{print $$3}' | sed 's/go//g')"; else echo "Go:            Not installed"; fi
	@if command -v lua >/dev/null 2>&1; then echo "Lua:           $$(lua -v | awk '{print $$2}')"; else echo "Lua:           Not installed"; fi
	@if command -v haproxy >/dev/null 2>&1; then echo "HAProxy:       $$(haproxy -v | head -n1 | awk '{print $$3}')"; else echo "HAProxy:       Not installed"; fi
	@if command -v docker >/dev/null 2>&1; then echo "Docker:        $$(docker --version | awk '{print $$3}' | sed 's/,//g')"; else echo "Docker:        Not installed"; fi
	@if docker compose version >/dev/null 2>&1; then echo "Docker Compose: $$(docker compose version | awk '{print $$4}')"; elif docker-compose --version >/dev/null 2>&1; then echo "Docker Compose: $$(docker-compose --version | awk '{print $$3}' | sed 's/,//g')"; else echo "Docker Compose: Not installed"; fi

# Update Go version in all go.mod files
update-go-version:
	@echo "🔄 Updating Go version to $(GO_VERSION) (toolchain $(GO_TOOLCHAIN_VERSION))..."
	@./scripts/update_go_version.sh
	@echo "✅ Go version updated in all go.mod files"

# Update HAProxy version in all project files
update-haproxy-version:
	@echo "🔄 Updating HAProxy version to $(HAPROXY_VERSION) in all files..."
	@./scripts/update_haproxy_version.sh
	@echo "✅ HAProxy version updated in all files"

# Update all versions in project files
update-versions: update-go-version update-haproxy-version verify-versions
	@echo "🔄 All versions have been updated according to versions.mk"
	@echo "To verify changes, use: git diff"

# Update all versions and run verification
update-all-versions:
	@echo "🔄 Running comprehensive version update..."
	@./scripts/update_all_versions.sh

# Verify version consistency across the project
verify-versions:
	@echo "🔍 Verifying version consistency across the project..."
	@./scripts/verify_versions.sh

# Check if environment meets version requirements
check-versions:
	@./scripts/check_versions.sh
