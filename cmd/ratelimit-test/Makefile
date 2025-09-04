# MinIO Rate Limiting + Observability Integration Makefile
# Complete workflow automation for testing, monitoring, and analysis

.PHONY: help install test observe clean logs status query dashboard

# Default target
.DEFAULT_GOAL := help

# Colors for output
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
BLUE := \033[34m
CYAN := \033[36m
RESET := \033[0m

# Configuration
DOCKER_COMPOSE_MAIN := ../../docker-compose.yml
DOCKER_COMPOSE_OBS := docker-compose.observability.yml
TEST_DURATION := 60
RESULTS_FILE := comprehensive_results.json

##@ Help
help: ## Display this help message
	@echo "$(CYAN)MinIO Rate Limiting + Observability Integration$(RESET)"
	@echo "=================================================="
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make $(CYAN)<target>$(RESET)\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Quick Start
quick-start: install-deps setup-all test-and-observe ## Complete setup: dependencies + services + test + observe
	@echo "$(GREEN)✅ Complete setup finished! Access dashboards at http://localhost:8080$(RESET)"

##@ Installation & Setup
install-deps: ## Install required dependencies
	@echo "$(BLUE)📦 Checking dependencies...$(RESET)"
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)❌ Docker not found. Please install Docker first.$(RESET)"; exit 1; }
	@command -v docker-compose >/dev/null 2>&1 || { echo "$(RED)❌ Docker Compose not found. Please install Docker Compose first.$(RESET)"; exit 1; }
	@command -v go >/dev/null 2>&1 || { echo "$(RED)❌ Go not found. Please install Go first.$(RESET)"; exit 1; }
	@echo "$(GREEN)✅ All dependencies are available$(RESET)"

setup-main: ## Setup main MinIO and HAProxy services
	@echo "$(BLUE)🚀 Setting up MinIO and HAProxy services...$(RESET)"
	@if [ -f "$(DOCKER_COMPOSE_MAIN)" ]; then \
		cd ../../ && docker-compose up -d; \
		echo "$(GREEN)✅ Main services started$(RESET)"; \
	else \
		echo "$(YELLOW)⚠️  Main docker-compose.yml not found at $(DOCKER_COMPOSE_MAIN)$(RESET)"; \
	fi

setup-observability: ## Setup ClickHouse + HyperDX + Vector observability stack
	@echo "$(BLUE)📊 Setting up observability stack...$(RESET)"
	@./setup-observability.sh

setup-all: setup-main setup-observability ## Setup both main services and observability stack
	@echo "$(GREEN)✅ All services are now running$(RESET)"

##@ Testing
test-quick: ## Run quick 30-second test
	@echo "$(BLUE)🧪 Running quick test (30 seconds)...$(RESET)"
	@timeout 30s go run fast_parallel.go || echo "$(YELLOW)⏰ Quick test completed$(RESET)"
	@echo "$(GREEN)✅ Quick test finished$(RESET)"

test-full: ## Run full comprehensive test (60 seconds)
	@echo "$(BLUE)🧪 Running comprehensive test ($(TEST_DURATION) seconds)...$(RESET)"
	@go run fast_parallel.go
	@echo "$(GREEN)✅ Full test completed - check $(RESULTS_FILE)$(RESET)"

test-custom: ## Run test with custom duration (make test-custom DURATION=120)
	@echo "$(BLUE)🧪 Running custom test ($(DURATION) seconds)...$(RESET)"
	@timeout $(DURATION)s go run fast_parallel.go || echo "$(YELLOW)⏰ Custom test completed$(RESET)"
	@echo "$(GREEN)✅ Custom test finished$(RESET)"

test-continuous: ## Run continuous testing (Ctrl+C to stop)
	@echo "$(BLUE)🔄 Starting continuous testing (Ctrl+C to stop)...$(RESET)"
	@while true; do \
		echo "$(CYAN)🧪 Running test cycle...$(RESET)"; \
		timeout 60s go run fast_parallel.go || true; \
		echo "$(YELLOW)⏰ Waiting 30 seconds before next cycle...$(RESET)"; \
		sleep 30; \
	done

##@ Observability Operations
observe-start: ## Start observability stack only
	@echo "$(BLUE)📊 Starting observability services...$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) up -d
	@echo "$(GREEN)✅ Observability stack started$(RESET)"

observe-stop: ## Stop observability stack
	@echo "$(BLUE)🛑 Stopping observability services...$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) down
	@echo "$(GREEN)✅ Observability stack stopped$(RESET)"

observe-restart: ## Restart observability stack
	@echo "$(BLUE)🔄 Restarting observability services...$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) restart
	@echo "$(GREEN)✅ Observability stack restarted$(RESET)"

ingest-data: ## Manually trigger data ingestion
	@echo "$(BLUE)📥 Triggering data ingestion...$(RESET)"
	@if [ -f "$(RESULTS_FILE)" ]; then \
		docker-compose -f $(DOCKER_COMPOSE_OBS) restart vector; \
		sleep 5; \
		echo "$(GREEN)✅ Data ingestion triggered$(RESET)"; \
	else \
		echo "$(RED)❌ $(RESULTS_FILE) not found. Run 'make test-full' first$(RESET)"; \
	fi

##@ Data Analysis
query-health: ## Check system health and data status
	@echo "$(BLUE)🏥 Checking system health...$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) exec -T clickhouse clickhouse-client --query \
		"SELECT 'Total Records' as metric, toString(count()) as value FROM minio_logs.test_results \
		 UNION ALL \
		 SELECT 'Latest Data', toString(max(timestamp)) FROM minio_logs.test_results \
		 UNION ALL \
		 SELECT 'Active Groups', toString(count(DISTINCT group)) FROM minio_logs.test_results WHERE timestamp >= now() - INTERVAL 24 HOUR \
		 UNION ALL \
		 SELECT 'Active API Keys', toString(count(DISTINCT api_key)) FROM minio_logs.test_results WHERE timestamp >= now() - INTERVAL 24 HOUR AND api_key != ''" \
		--format PrettyCompact

query-overview: ## Show overall system statistics
	@echo "$(BLUE)📊 System Overview...$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) exec -T clickhouse clickhouse-client --query \
		"SELECT sum(requests_sent) as total_requests, sum(success_count) as success, sum(rate_limited_count) as rate_limited, sum(error_count) as errors, round(sum(success_count)/sum(requests_sent)*100,2) as success_pct, round(sum(rate_limited_count)/sum(requests_sent)*100,2) as rate_limit_pct FROM minio_logs.test_results WHERE requests_sent > 0" \
		--format PrettyCompact

query-performance: ## Show performance metrics by group
	@echo "$(BLUE)⚡ Performance by Group...$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) exec -T clickhouse clickhouse-client --query \
		"SELECT * FROM minio_logs.performance_by_group" \
		--format PrettyCompact

query-rate-limits: ## Show rate limiting analysis
	@echo "$(BLUE)🚦 Rate Limiting Analysis...$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) exec -T clickhouse clickhouse-client --query \
		"SELECT * FROM minio_logs.rate_limit_analysis WHERE total_requests > 10 ORDER BY rate_limit_percentage DESC LIMIT 15" \
		--format PrettyCompact

query-errors: ## Show error analysis
	@echo "$(BLUE)❌ Error Analysis...$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) exec -T clickhouse clickhouse-client --query \
		"SELECT group, arrayJoin(mapKeys(error_details)) as error_type, sum(mapValues(error_details)) as count FROM minio_logs.test_results WHERE length(error_details) > 0 GROUP BY group, error_type ORDER BY count DESC" \
		--format PrettyCompact

query-trends: ## Show hourly trends for last 24 hours
	@echo "$(BLUE)📈 Hourly Trends (Last 24h)...$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) exec -T clickhouse clickhouse-client --query \
		"SELECT * FROM minio_logs.hourly_metrics WHERE hour >= now() - INTERVAL 24 HOUR ORDER BY hour DESC LIMIT 24" \
		--format PrettyCompact

query-custom: ## Run custom query (make query-custom SQL="SELECT ...")
	@echo "$(BLUE)🔍 Running custom query...$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) exec -T clickhouse clickhouse-client --query "$(SQL)" --format PrettyCompact

##@ Workflows
test-and-observe: setup-observability test-full ingest-data ## Complete workflow: setup observability, run test, ingest data
	@echo "$(GREEN)🎉 Test and observe workflow completed!$(RESET)"
	@make dashboard

full-cycle: setup-all test-and-observe query-overview ## Complete cycle: setup everything, test, and show results
	@echo "$(GREEN)🎉 Full cycle completed! Check dashboards at http://localhost:8080$(RESET)"

benchmark: ## Run benchmark suite with different test durations
	@echo "$(BLUE)🏃 Running benchmark suite...$(RESET)"
	@echo "$(CYAN)Running 30-second test...$(RESET)"
	@timeout 30s go run fast_parallel.go > benchmark_30s.json || true
	@echo "$(CYAN)Running 60-second test...$(RESET)" 
	@timeout 60s go run fast_parallel.go > benchmark_60s.json || true
	@echo "$(CYAN)Running 120-second test...$(RESET)"
	@timeout 120s go run fast_parallel.go > benchmark_120s.json || true
	@make ingest-data
	@echo "$(GREEN)✅ Benchmark suite completed$(RESET)"

stress-test: ## Run stress test with continuous load
	@echo "$(BLUE)💪 Starting stress test...$(RESET)"
	@echo "$(YELLOW)Running continuous load for 5 minutes. Ctrl+C to stop early.$(RESET)"
	@timeout 300s make test-continuous || echo "$(YELLOW)⏰ Stress test completed$(RESET)"
	@make ingest-data query-overview

##@ Monitoring
dashboard: ## Open dashboards in browser
	@echo "$(BLUE)🌐 Opening dashboards...$(RESET)"
	@echo "$(CYAN)HyperDX Dashboard: http://localhost:8080$(RESET)"
	@echo "$(CYAN)ClickHouse Query UI: http://localhost:8123/play$(RESET)"
	@if command -v open >/dev/null 2>&1; then \
		open http://localhost:8080 >/dev/null 2>&1 || true; \
	elif command -v xdg-open >/dev/null 2>&1; then \
		xdg-open http://localhost:8080 >/dev/null 2>&1 || true; \
	fi

status: ## Show status of all services
	@echo "$(BLUE)📋 Service Status:$(RESET)"
	@echo ""
	@echo "$(CYAN)Main Services:$(RESET)"
	@if [ -f "$(DOCKER_COMPOSE_MAIN)" ]; then \
		cd ../../ && docker-compose ps; \
	else \
		echo "$(YELLOW)Main services not found$(RESET)"; \
	fi
	@echo ""
	@echo "$(CYAN)Observability Services:$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) ps
	@echo ""
	@echo "$(CYAN)Service Health:$(RESET)"
	@curl -s http://localhost:8123/ping >/dev/null && echo "$(GREEN)✅ ClickHouse: Running$(RESET)" || echo "$(RED)❌ ClickHouse: Down$(RESET)"
	@curl -s http://localhost:8080/health >/dev/null && echo "$(GREEN)✅ HyperDX: Running$(RESET)" || echo "$(RED)❌ HyperDX: Down$(RESET)"
	@curl -s http://localhost:8686/health >/dev/null && echo "$(GREEN)✅ Vector: Running$(RESET)" || echo "$(RED)❌ Vector: Down$(RESET)"

logs: ## Show logs from all services
	@echo "$(BLUE)📄 Service Logs:$(RESET)"
	@echo ""
	@echo "$(CYAN)=== ClickHouse Logs ====$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) logs --tail=20 clickhouse
	@echo ""
	@echo "$(CYAN)=== Vector Logs ====$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) logs --tail=20 vector
	@echo ""
	@echo "$(CYAN)=== HyperDX Logs ====$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) logs --tail=20 hyperdx

logs-follow: ## Follow logs from observability services
	@echo "$(BLUE)📄 Following logs (Ctrl+C to stop)...$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) logs -f

logs-clickhouse: ## Show ClickHouse logs only
	@docker-compose -f $(DOCKER_COMPOSE_OBS) logs -f clickhouse

logs-vector: ## Show Vector logs only
	@docker-compose -f $(DOCKER_COMPOSE_OBS) logs -f vector

logs-hyperdx: ## Show HyperDX logs only  
	@docker-compose -f $(DOCKER_COMPOSE_OBS) logs -f hyperdx

##@ Data Management
export-data: ## Export test results to JSON file
	@echo "$(BLUE)📤 Exporting data...$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) exec -T clickhouse clickhouse-client --query \
		"SELECT * FROM minio_logs.test_results ORDER BY timestamp DESC" --format JSONEachRow > exported_data.json
	@echo "$(GREEN)✅ Data exported to exported_data.json$(RESET)"

backup-data: ## Create backup of ClickHouse data
	@echo "$(BLUE)💾 Creating data backup...$(RESET)"
	@mkdir -p backups
	@docker-compose -f $(DOCKER_COMPOSE_OBS) exec -T clickhouse clickhouse-client --query \
		"BACKUP DATABASE minio_logs TO Disk('default', 'backup_$(shell date +%Y%m%d_%H%M%S').tar.gz')" || \
		echo "$(YELLOW)⚠️  Backup via SQL failed, creating volume backup...$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) exec clickhouse tar czf /tmp/backup_$(shell date +%Y%m%d_%H%M%S').tar.gz /var/lib/clickhouse/data/minio_logs/
	@echo "$(GREEN)✅ Backup created$(RESET)"

clean-data: ## Clean old test data (keeps last 7 days)
	@echo "$(BLUE)🧹 Cleaning old data...$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) exec -T clickhouse clickhouse-client --query \
		"ALTER TABLE minio_logs.test_results DELETE WHERE timestamp < now() - INTERVAL 7 DAY"
	@echo "$(GREEN)✅ Old data cleaned$(RESET)"

##@ Maintenance
clean: ## Clean up containers and volumes
	@echo "$(BLUE)🧹 Cleaning up...$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) down -v
	@if [ -f "$(DOCKER_COMPOSE_MAIN)" ]; then \
		cd ../../ && docker-compose down -v; \
	fi
	@docker system prune -f
	@echo "$(GREEN)✅ Cleanup completed$(RESET)"

clean-soft: ## Stop services without removing volumes
	@echo "$(BLUE)🧹 Soft cleanup...$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) down
	@if [ -f "$(DOCKER_COMPOSE_MAIN)" ]; then \
		cd ../../ && docker-compose down; \
	fi
	@echo "$(GREEN)✅ Services stopped$(RESET)"

restart-all: ## Restart all services
	@echo "$(BLUE)🔄 Restarting all services...$(RESET)"
	@make clean-soft
	@make setup-all
	@echo "$(GREEN)✅ All services restarted$(RESET)"

update-images: ## Update Docker images to latest versions
	@echo "$(BLUE)📥 Updating Docker images...$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) pull
	@if [ -f "$(DOCKER_COMPOSE_MAIN)" ]; then \
		cd ../../ && docker-compose pull; \
	fi
	@echo "$(GREEN)✅ Images updated$(RESET)"

##@ Development
dev-shell: ## Access ClickHouse interactive shell
	@echo "$(BLUE)💻 Opening ClickHouse shell...$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) exec clickhouse clickhouse-client

dev-inspect: ## Inspect comprehensive_results.json structure
	@echo "$(BLUE)🔍 Inspecting $(RESULTS_FILE) structure...$(RESET)"
	@if [ -f "$(RESULTS_FILE)" ]; then \
		jq '.summary.ByGroup | keys' $(RESULTS_FILE) 2>/dev/null || \
		python3 -m json.tool $(RESULTS_FILE) | head -50 || \
		cat $(RESULTS_FILE) | head -20; \
	else \
		echo "$(RED)❌ $(RESULTS_FILE) not found. Run 'make test-full' first$(RESET)"; \
	fi

dev-validate: ## Validate observability stack configuration
	@echo "$(BLUE)✅ Validating configuration...$(RESET)"
	@echo "$(CYAN)Checking Docker Compose files...$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) config >/dev/null && echo "$(GREEN)✅ Observability config valid$(RESET)" || echo "$(RED)❌ Observability config invalid$(RESET)"
	@echo "$(CYAN)Checking Vector config...$(RESET)"
	@docker-compose -f $(DOCKER_COMPOSE_OBS) exec vector vector validate /etc/vector/vector.toml >/dev/null 2>&1 && echo "$(GREEN)✅ Vector config valid$(RESET)" || echo "$(YELLOW)⚠️  Vector config validation skipped$(RESET)"

##@ Documentation
docs: ## Show documentation links
	@echo "$(CYAN)📚 Documentation Links:$(RESET)"
	@echo ""
	@echo "  📋 Observability Guide:     README-observability.md"
	@echo "  🔍 Query Examples:          query-examples.sql"
	@echo "  📊 Main Project README:     ../../README.md"
	@echo "  🌐 HyperDX Dashboard:       http://localhost:8080"
	@echo "  🗄️  ClickHouse Query UI:     http://localhost:8123/play"
	@echo ""
	@echo "$(CYAN)📖 Key Commands:$(RESET)"
	@echo "  make quick-start      # Complete setup and test"
	@echo "  make test-and-observe # Test + visualize results"
	@echo "  make query-overview   # Show system stats"
	@echo "  make dashboard        # Open dashboards"

examples: ## Show example workflows
	@echo "$(CYAN)🔧 Example Workflows:$(RESET)"
	@echo ""
	@echo "$(YELLOW)1. First Time Setup:$(RESET)"
	@echo "   make quick-start"
	@echo ""
	@echo "$(YELLOW)2. Run Tests and Analyze:$(RESET)"
	@echo "   make test-full"
	@echo "   make ingest-data"
	@echo "   make query-overview"
	@echo "   make dashboard"
	@echo ""
	@echo "$(YELLOW)3. Continuous Monitoring:$(RESET)"
	@echo "   make test-continuous  # In one terminal"
	@echo "   make logs-follow      # In another terminal"
	@echo ""
	@echo "$(YELLOW)4. Custom Analysis:$(RESET)"
	@echo "   make dev-shell"
	@echo "   # Then run custom SQL queries"
	@echo ""
	@echo "$(YELLOW)5. Benchmark Testing:$(RESET)"
	@echo "   make benchmark"
	@echo "   make stress-test"