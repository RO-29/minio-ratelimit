# MinIO Rate Limiting Test Suite
# Comprehensive testing solution for MinIO rate limiting features

# Define build directory and binary name
BUILD_DIR := build
BINARY_NAME := minio-ratelimit-test
DOCKER_IMAGE := minio-ratelimit-test:latest
TEST_DURATION := 30s

# Auto-detect if we're running from root or cmd/ratelimit-test directory
ifeq ($(shell test -f haproxy/config/generated_service_accounts.json && echo "root"), root)
    CONFIG_FILE := haproxy/config/generated_service_accounts.json
    PROJECT_ROOT := .
else ifeq ($(shell test -f ../../haproxy/config/generated_service_accounts.json && echo "subdir"), subdir)
    CONFIG_FILE := ../../haproxy/config/generated_service_accounts.json
    PROJECT_ROOT := ../..
else
    CONFIG_FILE := haproxy/config/generated_service_accounts.json
    PROJECT_ROOT := .
endif

.PHONY: help setup clean build test unit-test docker-build docker-run docker-test \
        stress-test quick-test json-export show-test-summary lint coverage \
        local-test docker-test wait-for-services

# Colors for prettier output
CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
BLUE := \033[34m
RESET := \033[0m

##@ Help & Setup
help: ## Display this help
	@echo "$(CYAN)MinIO Rate Limiting Test Suite$(RESET)"
	@echo "========================================"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

setup: ## Set up the environment
	@echo "$(BLUE)🔧 Setting up environment...$(RESET)"
	@mkdir -p $(BUILD_DIR)
	@mkdir -p coverage
	@go mod tidy
	@echo "$(GREEN)✅ Environment set up complete!$(RESET)"

clean: ## Clean up build artifacts
	@echo "$(BLUE)🧹 Cleaning up build artifacts...$(RESET)"
	@rm -rf $(BUILD_DIR)/*
	@rm -f coverage/*.out coverage/*.html
	@rm -f *.json
	@echo "$(GREEN)✅ Cleanup complete!$(RESET)"

##@ Build Operations
build: setup ## Build the test binary
	@echo "$(BLUE)� Building test binary...$(RESET)"
	@go build -o $(BUILD_DIR)/$(BINARY_NAME) *.go
	@echo "$(GREEN)✅ Build complete: $(BUILD_DIR)/$(BINARY_NAME)$(RESET)"

##@ Testing & Data (Local Mode)
unit-test: ## Run unit tests
	@echo "$(CYAN)🧪 Running unit tests...$(RESET)"
	@go test -v ./... || (echo "$(RED)❌ Unit tests failed$(RESET)" && exit 1)
	@echo "$(GREEN)✅ Unit tests passed!$(RESET)"

lint: ## Run linting checks
	@echo "$(CYAN)🔍 Running linting checks...$(RESET)"
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run || echo "$(YELLOW)⚠️  Linting issues found$(RESET)"; \
	else \
		echo "$(YELLOW)⚠️  golangci-lint not installed, skipping...$(RESET)"; \
	fi

coverage: setup ## Generate test coverage
	@echo "$(CYAN)📊 Generating test coverage...$(RESET)"
	@go test -coverprofile=coverage/coverage.out ./...
	@go tool cover -html=coverage/coverage.out -o coverage/coverage.html
	@echo "$(GREEN)✅ Coverage report generated: coverage/coverage.html$(RESET)"

test: build ## Run MinIO rate limiting test (local mode)
	@echo "$(CYAN)🧪 Running MinIO rate limiting test...$(RESET)"
	@echo "$(BLUE)🧪 Running comprehensive test ($(TEST_DURATION))...$(RESET)"
	@./$(BUILD_DIR)/$(BINARY_NAME) -config=$(CONFIG_FILE) -duration=$(TEST_DURATION) > comprehensive_results.json
	@echo "$(GREEN)✅ Test completed - results saved to comprehensive_results.json$(RESET)"
	@$(MAKE) show-test-summary

quick-test: build ## Run a quick test with minimal duration
	@echo "$(CYAN)🚀 Running quick test (10s)...$(RESET)"
	@./$(BUILD_DIR)/$(BINARY_NAME) -config=$(CONFIG_FILE) -duration=10s -accounts=1 > quick_test_results.json
	@echo "$(GREEN)✅ Quick test completed - results saved to quick_test_results.json$(RESET)"
	@python3 -c "import json; data=json.load(open('quick_test_results.json')); print(f\"Total Requests: {data['summary']['TotalRequests']}\"); print(f\"Success Rate: {round(data['summary']['TotalSuccess']/data['summary']['TotalRequests']*100,1)}%\");" 2>/dev/null || echo "$(YELLOW)⚠️  Could not parse results$(RESET)"

stress-test: build ## Run stress test focusing on premium tier
	@echo "$(CYAN)💪 Running premium stress test...$(RESET)"
	@./$(BUILD_DIR)/$(BINARY_NAME) -config=$(CONFIG_FILE) -stress-premium -duration=60s > stress_test_results.json
	@echo "$(GREEN)✅ Stress test completed - results saved to stress_test_results.json$(RESET)"
	@$(MAKE) show-test-summary FILE=stress_test_results.json

json-export: build ## Run test with JSON export enabled
	@echo "$(CYAN)📊 Running test with detailed JSON export...$(RESET)"
	@./$(BUILD_DIR)/$(BINARY_NAME) -config=$(CONFIG_FILE) -duration=$(TEST_DURATION) -json -output=detailed_results.json > test_output.log
	@echo "$(GREEN)✅ Test with JSON export completed!$(RESET)"

show-test-summary: ## Show quick test results summary
	@echo "$(CYAN)📊 Test Results Summary:$(RESET)"
	@python3 -c "import json; data=json.load(open('comprehensive_results.json')); print(f\"Total Tests: {data['summary']['TotalTests']}\"); print(f\"Total Requests: {data['summary']['TotalRequests']}\"); print(f\"Success Rate: {round(data['summary']['TotalSuccess']/data['summary']['TotalRequests']*100,1)}%\"); print(f\"Rate Limited: {data['summary']['TotalLimited']} ({round(data['summary']['TotalLimited']/data['summary']['TotalRequests']*100,1)}%)\")" 2>/dev/null || echo "$(YELLOW)⚠️  Run 'make test' first to generate results$(RESET)"

##@ Docker Operations
docker-build: ## Build Docker image
	@echo "$(CYAN)🐳 Building Docker image...$(RESET)"
	@docker build -t $(DOCKER_IMAGE) -f Dockerfile ..
	@echo "$(GREEN)✅ Docker image built: $(DOCKER_IMAGE)$(RESET)"

docker-run: docker-build ## Run the test in Docker container
	@echo "$(CYAN)🐳 Running test in Docker container...$(RESET)"
	@docker run --rm -v $(PWD)/docker-results:/results $(DOCKER_IMAGE) -duration=$(TEST_DURATION) -json -output=/results/docker_results.json
	@echo "$(GREEN)✅ Docker test completed - results in docker-results/docker_results.json$(RESET)"

docker-test: ## Build and run test in Docker
	@$(MAKE) docker-build
	@$(MAKE) docker-run

##@ Advanced Features
load-test: build ## Run extended load test (5 minutes)
	@echo "$(CYAN)💪 Running extended load test...$(RESET)"
	@echo "$(YELLOW)⚠️  This will run for 5 minutes and generate significant data$(RESET)"
	@./$(BUILD_DIR)/$(BINARY_NAME) -duration=5m > comprehensive_results_load.json
	@echo "$(GREEN)✅ Load test completed - results saved to comprehensive_results_load.json$(RESET)"
	@echo "$(YELLOW)⚠️  This will run for 5 minutes and generate significant data$(RESET)"
	@timeout 300 ./build/minio-ratelimit-test > comprehensive_results_load.json || echo "$(YELLOW)⏰ Load test completed$(RESET)"
	@mv comprehensive_results_load.json comprehensive_results.json
	@$(MAKE) ingest
	@echo "$(GREEN)✅ Load test completed and data ingested$(RESET)"
