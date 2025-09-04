# MinIO Rate Limiting + HyperDX ClickStack Integration
# Complete observability solution with ClickHouse 25.8+ JSON capabilities

.PHONY: help setup test ingest analyze dashboard clean

# Colors
CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
BLUE := \033[34m
RESET := \033[0m

##@ Help
help: ## Display this help
	@echo "$(CYAN)MinIO Rate Limiting + HyperDX ClickStack$(RESET)"
	@echo "========================================"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

wait-for-services: ## Wait for all services to be ready
	@echo "$(BLUE)🔄 Waiting for services to be ready...$(RESET)"
	@timeout 120 bash -c 'until curl -sf http://localhost:8080 >/dev/null; do echo "$(YELLOW)⏳ Waiting for HyperDX...$(RESET)"; sleep 5; done' || echo "$(RED)⚠️  HyperDX may still be starting$(RESET)"
	@timeout 60 bash -c 'until curl -sf http://localhost:8123/ping >/dev/null; do echo "$(YELLOW)⏳ Waiting for ClickHouse...$(RESET)"; sleep 3; done'
	@echo "$(GREEN)✅ Services are ready!$(RESET)"


##@ Testing & Data
test: ## Run MinIO rate limiting test
	@echo "$(CYAN)🧪 Running MinIO rate limiting test...$(RESET)"
	@echo "$(BLUE)🔧 Building test binary...$(RESET)"
	@go build -o build/minio-ratelimit-test *.go
	@echo "$(BLUE)🧪 Running comprehensive test...$(RESET)"
	@./build/minio-ratelimit-test > comprehensive_results.json
	@echo "$(GREEN)✅ Test completed - results saved to comprehensive_results.json$(RESET)"
	@$(MAKE) show-test-summary

show-test-summary: ## Show quick test results summary
	@echo "$(CYAN)📊 Test Results Summary:$(RESET)"
	@python3 -c "import json; data=json.load(open('comprehensive_results.json')); print(f\"Total Tests: {data['summary']['TotalTests']}\"); print(f\"Total Requests: {data['summary']['TotalRequests']}\"); print(f\"Success Rate: {round(data['summary']['TotalSuccess']/data['summary']['TotalRequests']*100,1)}%\"); print(f\"Rate Limited: {data['summary']['TotalLimited']} ({round(data['summary']['TotalLimited']/data['summary']['TotalRequests']*100,1)}%)\")" 2>/dev/null || echo "$(YELLOW)⚠️  Run 'make test' first to generate results$(RESET)"

##@ Advanced Features
load-test: ## Run extended load test (5 minutes)
	@echo "$(CYAN)💪 Running extended load test...$(RESET)"
	@echo "$(YELLOW)⚠️  This will run for 5 minutes and generate significant data$(RESET)"
	@timeout 300 ./build/minio-ratelimit-test > comprehensive_results_load.json || echo "$(YELLOW)⏰ Load test completed$(RESET)"
	@mv comprehensive_results_load.json comprehensive_results.json
	@$(MAKE) ingest
	@echo "$(GREEN)✅ Load test completed and data ingested$(RESET)"
