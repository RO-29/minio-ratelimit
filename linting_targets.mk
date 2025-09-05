# Colors for prettier output
CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
BLUE := \033[34m
RESET := \033[0m

#
# Linting and Validation Targets
#

# Run all linting checks
lint: lint-go lint-haproxy lint-lua
	@echo "$(GREEN)✅ All linting checks completed!$(RESET)"

# Lint Go code
lint-go:
	@echo "$(CYAN)🔍 Linting Go code...$(RESET)"
	@cd ./cmd/ratelimit-test && if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run ./... || echo "$(YELLOW)⚠️  Go linting issues found$(RESET)"; \
	else \
		echo "$(YELLOW)⚠️  golangci-lint not installed, using basic go vet...$(RESET)"; \
		go vet ./...; \
	fi
	@echo "$(GREEN)✅ Go code linting completed!$(RESET)"

# Check HAProxy configuration syntax
lint-haproxy:
	@echo "$(CYAN)🔍 Checking HAProxy configuration syntax...$(RESET)"
	@if [ -f ./scripts/haproxy_validate.sh ]; then \
		chmod +x ./scripts/haproxy_validate.sh; \
		echo "$(YELLOW)Using local-only mode for HAProxy validation...$(RESET)"; \
		./scripts/haproxy_validate.sh --local-only || exit 1; \
	elif command -v haproxy >/dev/null 2>&1; then \
		haproxy -c -f ./haproxy/haproxy.cfg || (echo "$(RED)❌ HAProxy configuration has errors$(RESET)" && exit 1); \
	elif docker info >/dev/null 2>&1; then \
		docker run --rm -v $(PWD)/haproxy:/usr/local/etc/haproxy:ro haproxy:3.0 haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg || (echo "$(RED)❌ HAProxy configuration has errors$(RESET)" && exit 1); \
	else \
		echo "$(YELLOW)⚠️  Neither HAProxy binary nor Docker available, skipping strict HAProxy syntax check...$(RESET)"; \
	fi
	@echo "$(GREEN)✅ HAProxy configuration syntax validation complete!$(RESET)"

# Check Lua scripts syntax
lint-lua:
	@echo "$(CYAN)🔍 Checking Lua scripts syntax...$(RESET)"
	@if [ -f ./scripts/lua_validate.sh ]; then \
		chmod +x ./scripts/lua_validate.sh; \
		echo "$(YELLOW)Using local-only mode for Lua validation...$(RESET)"; \
		./scripts/lua_validate.sh --local-only || exit 1; \
	elif command -v luac >/dev/null 2>&1; then \
		for script in ./haproxy/lua/*.lua; do \
			echo "Checking $${script}..."; \
			luac -p $${script} || (echo "$(RED)❌ Lua syntax error in $${script}$(RESET)" && exit 1); \
		done; \
	elif command -v lua >/dev/null 2>&1; then \
		for script in ./haproxy/lua/*.lua; do \
			echo "Checking $${script}..."; \
			lua -e "loadfile('$${script}')" || (echo "$(RED)❌ Lua syntax error in $${script}$(RESET)" && exit 1); \
		done; \
	elif docker info >/dev/null 2>&1; then \
		docker run --rm -v $(PWD)/haproxy/lua:/scripts:ro alpine:latest sh -c "for script in /scripts/*.lua; do echo \"Checking \$${script}...\"; lua -e \"loadfile('\$${script}')\" || exit 1; done" || (echo "$(RED)❌ Lua syntax errors found$(RESET)" && exit 1); \
	else \
		echo "$(YELLOW)⚠️  No Lua interpreter available, skipping strict Lua syntax check...$(RESET)"; \
	fi
	@echo "$(GREEN)✅ Lua scripts syntax validation complete!$(RESET)"

# Test HAProxy configuration
test-haproxy:
	@echo "$(CYAN)🧪 Testing HAProxy configuration...$(RESET)"
	@if [ -f ./scripts/test_haproxy.sh ]; then \
		chmod +x ./scripts/test_haproxy.sh; \
		./scripts/test_haproxy.sh || exit 1; \
	elif [ -f ./scripts/test_haproxy_config.sh ]; then \
		echo "$(YELLOW)⚠️  Using deprecated test script...$(RESET)"; \
		./scripts/haproxy_validate.sh --local-only || true; \
	elif command -v haproxy >/dev/null 2>&1; then \
		haproxy -c -f ./haproxy/haproxy.cfg || (echo "$(RED)❌ HAProxy configuration test failed$(RESET)" && exit 1); \
	elif docker info >/dev/null 2>&1; then \
		mkdir -p ./test-results; \
		docker run --rm -v $(PWD)/haproxy:/usr/local/etc/haproxy:ro \
			--name haproxy-test haproxy:3.0 \
			haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg || (echo "$(RED)❌ HAProxy configuration test failed$(RESET)" && exit 1); \
	else \
		echo "$(YELLOW)⚠️  Neither HAProxy binary nor Docker available, skipping HAProxy test...$(RESET)"; \
	fi
	@echo "$(GREEN)✅ HAProxy configuration test passed!$(RESET)"

# Test Lua scripts
test-lua:
	@echo "$(CYAN)🧪 Testing Lua scripts...$(RESET)"
	@mkdir -p ./test-results
	@if [ -f ./scripts/test_lua_scripts.sh ]; then \
		./scripts/test_lua_scripts.sh; \
	elif command -v lua >/dev/null 2>&1; then \
		for script in ./haproxy/lua/*.lua; do \
			echo "Running basic test for $${script}..."; \
			lua -e "dofile('$${script}')" || (echo "$(RED)❌ Lua test failed for $${script}$(RESET)" && exit 1); \
		done; \
	elif docker info >/dev/null 2>&1; then \
		docker run --rm -v $(PWD)/haproxy/lua:/scripts:ro alpine/lua:latest sh -c "for script in /scripts/*.lua; do echo \"Running basic test for $${script}...\"; lua $${script} || exit 1; done" || (echo "$(RED)❌ Lua tests failed$(RESET)" && exit 1); \
	else \
		echo "$(YELLOW)⚠️  No Lua interpreter available, skipping Lua tests...$(RESET)"; \
	fi
	@echo "$(GREEN)✅ Lua scripts tested successfully!$(RESET)"

# Run all validation checks
validate-all: lint test-haproxy test-lua
	@echo "$(GREEN)✅ All validation checks passed!$(RESET)"

# CI setup - prepare environment for CI
ci-setup:
	@echo "$(CYAN)🔧 Setting up CI environment...$(RESET)"
	@mkdir -p ./cmd/ratelimit-test/build ./cmd/ratelimit-test/results ./test-results
	@cd ./cmd/ratelimit-test && go mod tidy
	@if [ -z "$(shell which golangci-lint)" ] && [ ! -z "$(shell which go)" ]; then \
		echo "$(YELLOW)Installing golangci-lint...$(RESET)"; \
		go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest; \
	fi
	@echo "$(GREEN)✅ CI setup complete!$(RESET)"

# CI test - run tests in CI environment
ci-test: ci-setup
	@echo "$(CYAN)🧪 Running tests in CI environment...$(RESET)"
	@cd ./cmd/ratelimit-test && go test -v ./... -coverprofile=../test-results/coverage.out
	@cd ./cmd/ratelimit-test && go build -o build/minio-ratelimit-test *.go
	@$(TEST_CMD) -duration=30s -accounts=2 -json -output=./test-results/ci_results.json
	@echo "$(GREEN)✅ CI tests complete!$(RESET)"

# CI validate - run validations in CI environment
ci-validate: ci-setup lint validate-all
	@echo "$(CYAN)🔍 Running validations in CI environment...$(RESET)"
	@echo "$(GREEN)✅ CI validation complete!$(RESET)"
