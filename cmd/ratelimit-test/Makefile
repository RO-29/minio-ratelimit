# MinIO Rate Limiting + ClickHouse Observability Integration
# Simplified working version

.PHONY: help setup test analyze dashboard clean

# Colors
CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RESET := \033[0m

##@ Help
help: ## Display this help
	@echo "$(CYAN)MinIO Rate Limiting + Observability (Simple)$(RESET)"
	@echo "============================================="
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(CYAN)%-15s$(RESET) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Setup
setup: ## Setup ClickHouse observability stack
	@echo "$(CYAN)🚀 Setting up ClickHouse observability...$(RESET)"
	@docker-compose -f docker-compose.observability.yml up -d
	@echo "$(GREEN)✅ ClickHouse started - waiting for it to be ready...$(RESET)"
	@sleep 10
	@curl -s http://localhost:8123/ping > /dev/null && echo "$(GREEN)✅ ClickHouse is ready!$(RESET)" || echo "$(YELLOW)⚠️  ClickHouse may still be starting...$(RESET)"

status: ## Check service status
	@echo "$(CYAN)📋 Service Status:$(RESET)"
	@docker-compose -f docker-compose.observability.yml ps
	@echo ""
	@curl -s http://localhost:8123/ping > /dev/null && echo "$(GREEN)✅ ClickHouse: Running$(RESET)" || echo "$(YELLOW)❌ ClickHouse: Down$(RESET)"

##@ Testing
test: ## Run MinIO rate limiting test
	@echo "$(CYAN)🧪 Running MinIO rate limiting test...$(RESET)"
	@go run *.go > comprehensive_results.json
	@echo "$(GREEN)✅ Test completed - results saved to comprehensive_results.json$(RESET)"

import: ## Import test results into ClickHouse
	@echo "$(CYAN)📥 Importing test results into ClickHouse...$(RESET)"
	@python3 import_data.py
	@echo "$(GREEN)✅ Data imported successfully$(RESET)"

test-and-import: test import ## Run test and import results
	@echo "$(GREEN)🎉 Test and import workflow completed!$(RESET)"

##@ Analysis
analyze: ## Show system overview
	@./analyze.sh overview

analyze-groups: ## Show performance by group  
	@./analyze.sh groups

analyze-latency: ## Show latency analysis
	@./analyze.sh latency

analyze-rate-limits: ## Show rate limiting effectiveness
	@./analyze.sh rate-limits

analyze-summary: ## Show executive summary
	@./analyze.sh summary

analyze-all: ## Run all analyses
	@echo "$(CYAN)📊 Complete Analysis Report$(RESET)"
	@echo "=========================="
	@./analyze.sh summary
	@echo ""
	@./analyze.sh groups
	@echo ""
	@./analyze.sh latency
	@echo ""
	@./analyze.sh rate-limits

##@ Dashboard
dashboard: ## Open ClickHouse web interface
	@echo "$(CYAN)🌐 Opening ClickHouse web interface...$(RESET)"
	@echo "$(CYAN)ClickHouse Query UI: http://localhost:8123/play$(RESET)"
	@if command -v open >/dev/null 2>&1; then \
		open http://localhost:8123/play >/dev/null 2>&1 || true; \
	elif command -v xdg-open >/dev/null 2>&1; then \
		xdg-open http://localhost:8123/play >/dev/null 2>&1 || true; \
	fi

query: ## Run custom ClickHouse query (make query SQL="SELECT ...")
	@echo "$(CYAN)🔍 Running custom query...$(RESET)"
	@curl "http://localhost:8123/" -d "$(SQL)" 2>/dev/null || echo "Usage: make query SQL=\"SELECT * FROM minio_logs.test_results\""

##@ Maintenance  
logs: ## Show ClickHouse logs
	@docker-compose -f docker-compose.observability.yml logs clickhouse

clean: ## Clean up containers and volumes
	@echo "$(CYAN)🧹 Cleaning up...$(RESET)"
	@docker-compose -f docker-compose.observability.yml down -v
	@echo "$(GREEN)✅ Cleanup completed$(RESET)"

restart: ## Restart services
	@echo "$(CYAN)🔄 Restarting services...$(RESET)"
	@docker-compose -f docker-compose.observability.yml restart
	@echo "$(GREEN)✅ Services restarted$(RESET)"

##@ Workflows
quick-start: setup test-and-import analyze-all dashboard ## Complete workflow: setup + test + analyze + dashboard
	@echo "$(GREEN)🎉 Quick start completed! ClickHouse web UI should be open.$(RESET)"

##@ Examples
examples: ## Show example commands
	@echo "$(CYAN)💡 Example Workflows:$(RESET)"
	@echo ""
	@echo "$(YELLOW)1. Complete Setup:$(RESET)"
	@echo "   make quick-start"
	@echo ""
	@echo "$(YELLOW)2. Run Test and Analyze:$(RESET)"
	@echo "   make test-and-import"
	@echo "   make analyze-all"
	@echo ""
	@echo "$(YELLOW)3. Custom Analysis:$(RESET)"
	@echo "   make query SQL=\"SELECT group, avg(avg_latency_ms) FROM minio_logs.test_results GROUP BY group\""
	@echo ""
	@echo "$(YELLOW)4. Access Web Interface:$(RESET)"
	@echo "   make dashboard"
	@echo ""
	@echo "$(YELLOW)5. Available Analysis Commands:$(RESET)"
	@echo "   ./analyze.sh help"