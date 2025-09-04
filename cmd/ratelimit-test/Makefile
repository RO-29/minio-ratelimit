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

##@ Setup & Management
setup: ## Setup HyperDX ClickStack (ClickHouse + HyperDX + MongoDB)
	@echo "$(CYAN)🚀 Setting up HyperDX ClickStack...$(RESET)"
	@docker-compose -f docker-compose.hyperdx.yml up -d
	@echo "$(GREEN)✅ HyperDX ClickStack started - waiting for services to be ready...$(RESET)"
	@echo "$(YELLOW)⏳ This may take 60-90 seconds for first-time setup...$(RESET)"
	@sleep 30
	@$(MAKE) wait-for-services

wait-for-services: ## Wait for all services to be ready
	@echo "$(BLUE)🔄 Waiting for services to be ready...$(RESET)"
	@timeout 120 bash -c 'until curl -sf http://localhost:8080 >/dev/null; do echo "$(YELLOW)⏳ Waiting for HyperDX...$(RESET)"; sleep 5; done' || echo "$(RED)⚠️  HyperDX may still be starting$(RESET)"
	@timeout 60 bash -c 'until curl -sf http://localhost:8123/ping >/dev/null; do echo "$(YELLOW)⏳ Waiting for ClickHouse...$(RESET)"; sleep 3; done'
	@echo "$(GREEN)✅ Services are ready!$(RESET)"

status: ## Check service status and health
	@echo "$(CYAN)📋 Service Status:$(RESET)"
	@docker-compose -f docker-compose.hyperdx.yml ps
	@echo ""
	@echo "$(CYAN)Service Health:$(RESET)"
	@curl -sf http://localhost:8123/ping >/dev/null && echo "$(GREEN)✅ ClickHouse: Running$(RESET)" || echo "$(RED)❌ ClickHouse: Down$(RESET)"
	@curl -sf http://localhost:8080 >/dev/null && echo "$(GREEN)✅ HyperDX: Running$(RESET)" || echo "$(RED)❌ HyperDX: Down$(RESET)"

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

ingest: ## Ingest comprehensive_results.json into HyperDX ClickStack (Python method)
	@echo "$(CYAN)📥 Ingesting test results into HyperDX ClickStack...$(RESET)"
	@python3 ingest_hyperdx.py
	@echo "$(GREEN)✅ Data ingestion completed$(RESET)"

ingest-direct: ## Direct ingestion using ClickHouse client (recommended)
	@echo "$(CYAN)📥 Direct ingestion using ClickHouse client...$(RESET)"
	@./ingest_direct.sh
	@echo "$(GREEN)✅ Direct ingestion completed$(RESET)"

test-and-ingest: test ingest ## Run test and ingest results in one command
	@echo "$(GREEN)🎉 Test and ingestion workflow completed!$(RESET)"

demo: setup test-and-ingest analyze ## Complete demo workflow
	@echo "$(GREEN)🎉 Complete demo finished! HyperDX ClickStack is ready for analysis.$(RESET)"
	@echo "$(YELLOW)💡 Try these commands:$(RESET)"
	@echo "  make analyze-performance"
	@echo "  make analyze-json"
	@echo "  make clickhouse  # Access ClickHouse UI"

##@ Analysis & Visualization
analyze: ## Show comprehensive system analysis
	@echo "$(CYAN)📊 System Analysis Overview:$(RESET)"
	@docker exec hyperdx clickhouse-client --query "SELECT 'Total Groups' as metric, toString(count(DISTINCT test_group)) as value FROM minio_logs.test_results UNION ALL SELECT 'Total Requests', toString(sum(requests_sent)) FROM minio_logs.test_results UNION ALL SELECT 'Success Rate %', toString(round(sum(success_count)/sum(requests_sent)*100,2)) FROM minio_logs.test_results UNION ALL SELECT 'Rate Limited %', toString(round(sum(rate_limited_count)/sum(requests_sent)*100,2)) FROM minio_logs.test_results FORMAT PrettyCompact" 2>/dev/null || echo "$(RED)❌ No data available. Run './ingest_direct.sh' first.$(RESET)"

analyze-performance: ## Show performance analysis by group
	@echo "$(CYAN)⚡ Performance Analysis:$(RESET)"
	@docker exec hyperdx clickhouse-client --query "SELECT test_group, sum(requests_sent) as requests, round(avg(avg_latency_ms),2) as avg_latency, round(sum(success_count)/sum(requests_sent)*100,2) as success_pct, round(sum(rate_limited_count)/sum(requests_sent)*100,2) as rate_limit_pct FROM minio_logs.test_results GROUP BY test_group ORDER BY requests DESC FORMAT PrettyCompact" 2>/dev/null || echo "$(RED)❌ No data available. Run './ingest_direct.sh' first.$(RESET)"

analyze-json: ## Demonstrate JSON analysis capabilities
	@echo "$(CYAN)🔍 JSON Analysis Examples:$(RESET)"
	@docker exec hyperdx clickhouse-client --query "SELECT test_group, JSONExtractKeys(toString(error_details)) as error_types, sum(error_count) as errors FROM minio_logs.test_results WHERE JSONLength(toString(error_details)) > 0 GROUP BY test_group, error_details ORDER BY errors DESC FORMAT PrettyCompact" 2>/dev/null || echo "$(RED)❌ No data available. Run './ingest_direct.sh' first.$(RESET)"

analyze-throttle: ## Show throttle events analysis
	@echo "$(CYAN)🚦 Throttle Events Analysis:$(RESET)"
	@curl -sf "http://localhost:8123/" -d "SELECT test_group, count() as events, round(avg(remaining_requests),2) as avg_remaining, round(avg(reset_in_seconds),2) as avg_reset_time FROM minio_logs.throttle_events GROUP BY test_group ORDER BY events DESC FORMAT PrettyCompact" 2>/dev/null || echo "$(RED)❌ No throttle data available.$(RESET)"

query: ## Run custom ClickHouse query (make query SQL="SELECT ...")
	@echo "$(CYAN)🔍 Running custom query:$(RESET)"
	@echo "$(BLUE)Query: $(SQL)$(RESET)"
	@curl -sf "http://localhost:8123/" -d "$(SQL)" 2>/dev/null || echo "$(RED)❌ Query failed. Check syntax and connection.$(RESET)"

##@ Dashboards & UI
dashboard: ## Open HyperDX dashboard
	@echo "$(CYAN)🌐 Opening HyperDX Dashboard...$(RESET)"
	@echo "$(CYAN)HyperDX UI: http://localhost:8080$(RESET)"
	@echo "$(CYAN)ClickHouse UI: http://localhost:8123/play$(RESET)"
	@if command -v open >/dev/null 2>&1; then \
		open http://localhost:8080 >/dev/null 2>&1 || true; \
		sleep 2; \
		open http://localhost:8123/play >/dev/null 2>&1 || true; \
	elif command -v xdg-open >/dev/null 2>&1; then \
		xdg-open http://localhost:8080 >/dev/null 2>&1 || true; \
		sleep 2; \
		xdg-open http://localhost:8123/play >/dev/null 2>&1 || true; \
	fi

hyperdx: ## Open HyperDX UI only
	@echo "$(CYAN)🎯 Opening HyperDX UI...$(RESET)"
	@if command -v open >/dev/null 2>&1; then \
		open http://localhost:8080 >/dev/null 2>&1 || true; \
	elif command -v xdg-open >/dev/null 2>&1; then \
		xdg-open http://localhost:8080 >/dev/null 2>&1 || true; \
	fi
	@echo "$(GREEN)📊 HyperDX available at: http://localhost:8080$(RESET)"

clickhouse: ## Open ClickHouse UI only
	@echo "$(CYAN)🗄️  Opening ClickHouse UI...$(RESET)"
	@if command -v open >/dev/null 2>&1; then \
		open http://localhost:8123/play >/dev/null 2>&1 || true; \
	elif command -v xdg-open >/dev/null 2>&1; then \
		xdg-open http://localhost:8123/play >/dev/null 2>&1 || true; \
	fi
	@echo "$(GREEN)🗄️  ClickHouse available at: http://localhost:8123/play$(RESET)"

##@ Maintenance
logs: ## Show logs from all services
	@echo "$(CYAN)📄 Service Logs:$(RESET)"
	@docker-compose -f docker-compose.hyperdx.yml logs --tail=20

logs-hyperdx: ## Show HyperDX logs only
	@docker-compose -f docker-compose.hyperdx.yml logs -f hyperdx

restart: ## Restart all services
	@echo "$(CYAN)🔄 Restarting HyperDX ClickStack...$(RESET)"
	@docker-compose -f docker-compose.hyperdx.yml restart
	@echo "$(GREEN)✅ Services restarted$(RESET)"

clean: ## Stop and remove all containers and volumes
	@echo "$(CYAN)🧹 Cleaning up HyperDX ClickStack...$(RESET)"
	@docker-compose -f docker-compose.hyperdx.yml down -v --remove-orphans
	@echo "$(GREEN)✅ Cleanup completed$(RESET)"

reset: clean setup ## Complete reset - clean and setup fresh
	@echo "$(GREEN)🔄 Complete reset finished!$(RESET)"

##@ Workflows
quick-start: setup test-and-ingest analyze dashboard ## Complete workflow: setup + test + ingest + analyze + dashboard
	@echo "$(GREEN)🎉 Quick start completed! HyperDX dashboard should be open.$(RESET)"
	@echo "$(YELLOW)💡 Try these commands:$(RESET)"
	@echo "  make analyze-performance"
	@echo "  make analyze-json"
	@echo "  make query SQL=\"SELECT * FROM minio_logs.test_results LIMIT 5\""

full-demo: ## Run complete demo with all features
	@echo "$(CYAN)🎬 Running complete MinIO → HyperDX demo...$(RESET)"
	@$(MAKE) setup
	@echo "$(BLUE)⏳ Waiting for services to stabilize...$(RESET)"
	@sleep 20
	@$(MAKE) test-and-ingest
	@echo "$(CYAN)📊 Showing analysis results:$(RESET)"
	@$(MAKE) analyze
	@$(MAKE) analyze-performance
	@$(MAKE) analyze-json
	@$(MAKE) dashboard
	@echo "$(GREEN)🎉 Demo completed! Explore the dashboards!$(RESET)"

##@ Advanced Features
load-test: ## Run extended load test (5 minutes)
	@echo "$(CYAN)💪 Running extended load test...$(RESET)"
	@echo "$(YELLOW)⚠️  This will run for 5 minutes and generate significant data$(RESET)"
	@timeout 300 ./build/minio-ratelimit-test > comprehensive_results_load.json || echo "$(YELLOW)⏰ Load test completed$(RESET)"
	@mv comprehensive_results_load.json comprehensive_results.json
	@$(MAKE) ingest
	@echo "$(GREEN)✅ Load test completed and data ingested$(RESET)"

export-results: ## Export analysis results to JSON files
	@echo "$(CYAN)📤 Exporting analysis results...$(RESET)"
	@mkdir -p exports
	@curl -sf "http://localhost:8123/" -d "SELECT * FROM minio_logs.performance_overview FORMAT JSONEachRow" > exports/performance_overview.json 2>/dev/null || echo "$(RED)❌ Export failed$(RESET)"
	@curl -sf "http://localhost:8123/" -d "SELECT * FROM minio_logs.rate_limit_analysis FORMAT JSONEachRow" > exports/rate_limit_analysis.json 2>/dev/null || echo "$(RED)❌ Export failed$(RESET)"
	@echo "$(GREEN)✅ Results exported to exports/ directory$(RESET)"

##@ Documentation & Examples
examples: ## Show example commands and queries
	@echo "$(CYAN)💡 Example Commands:$(RESET)"
	@echo ""
	@echo "$(YELLOW)1. Complete Setup:$(RESET)"
	@echo "   make quick-start"
	@echo ""
	@echo "$(YELLOW)2. Custom Analysis:$(RESET)"
	@echo "   make query SQL=\"SELECT test_group, avg(avg_latency_ms) FROM minio_logs.test_results GROUP BY test_group\""
	@echo ""
	@echo "$(YELLOW)3. JSON Analysis:$(RESET)"
	@echo "   make query SQL=\"SELECT JSON_VALUE(raw_data, '$.Method') as method, count() FROM minio_logs.test_results GROUP BY method\""
	@echo ""
	@echo "$(YELLOW)4. Time Series:$(RESET)"
	@echo "   make query SQL=\"SELECT * FROM minio_logs.hourly_metrics ORDER BY hour DESC LIMIT 24\""
	@echo ""
	@echo "$(YELLOW)5. Load Testing:$(RESET)"
	@echo "   make load-test"

show-urls: ## Show all access URLs
	@echo "$(CYAN)🔗 Access URLs:$(RESET)"
	@echo "$(GREEN)📊 HyperDX Dashboard: http://localhost:8080$(RESET)"
	@echo "$(GREEN)🗄️  ClickHouse Web UI:   http://localhost:8123/play$(RESET)"
	@echo "$(GREEN)🔍 ClickHouse HTTP API: http://localhost:8123$(RESET)"
	@echo "$(GREEN)📡 OTEL HTTP Endpoint:  http://localhost:4318$(RESET)"
	@echo "$(GREEN)📡 OTEL gRPC Endpoint:  localhost:4317$(RESET)"

validate: ## Validate setup and data integrity
	@echo "$(CYAN)✅ Validating setup...$(RESET)"
	@$(MAKE) status
	@echo ""
	@echo "$(CYAN)🔍 Data validation:$(RESET)"
	@curl -sf "http://localhost:8123/" -d "SELECT 'Test Results' as table_name, count() as records FROM minio_logs.test_results UNION ALL SELECT 'Throttle Events', count() FROM minio_logs.throttle_events UNION ALL SELECT 'Summary Records', count() FROM minio_logs.test_summary FORMAT PrettyCompact" 2>/dev/null || echo "$(RED)❌ No data found$(RESET)"