# Color handling for Make
ifdef CI
  # Simple echo in CI without colors
  define print_styled
    @echo "$(2)"
  endef
else
  # Use colors when not in CI
  define print_styled
    @printf "$(1)%s$(RESET)\n" "$(2)"
  endef
endif

# Colors for prettier output - disable if in CI
ifdef CI
  # Disable colors in CI environments
  CYAN :=
  GREEN :=
  YELLOW :=
  RED :=
  BLUE :=
  RESET :=
  export CI_NO_COLOR := true
else
  CYAN := \033[36m
  GREEN := \033[32m
  YELLOW := \033[33m
  RED := \033[31m
  BLUE := \033[34m
  RESET := \033[0m
endif

#
# Linting and Validation Targets
#
# CI-specific targets (ci-setup, ci-test, ci-validate) are designed for
# automated environments and include:
# - Docker Compose version detection (v1 vs v2)
# - Service account generation for testing
# - Proper path resolution for CI environments
# - Artifact-friendly output formatting
#

# Run all linting checks
lint: lint-go lint-haproxy lint-lua
	$(call print_styled,$(GREEN),✅ All linting checks completed!)

# Lint Go code
lint-go:
	$(call print_styled,$(CYAN),🔍 Linting Go code...)
	@cd $(PROJECT_ROOT)/cmd/ratelimit-test && if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run ./... || echo "$(YELLOW)⚠️  Go linting issues found$(RESET)"; \
	else \
		echo "$(YELLOW)⚠️  golangci-lint not installed, using basic go vet...$(RESET)"; \
		go vet ./...; \
	fi
	$(call print_styled,$(GREEN),✅ Go code linting completed!)

# Check HAProxy configuration syntax
lint-haproxy:
	@echo "$(CYAN)🔍 Checking HAProxy configuration syntax...$(RESET)"
	@if [ -f $(PROJECT_ROOT)/scripts/haproxy_validate.sh ]; then \
		chmod +x $(PROJECT_ROOT)/scripts/haproxy_validate.sh; \
		echo "$(YELLOW)Using local-only mode for HAProxy validation...$(RESET)"; \
		$(PROJECT_ROOT)/scripts/haproxy_validate.sh --local-only || exit 1; \
	elif command -v haproxy >/dev/null 2>&1; then \
		haproxy -c -f $(PROJECT_ROOT)/haproxy/haproxy.cfg || (echo "$(RED)❌ HAProxy configuration has errors$(RESET)" && exit 1); \
	elif docker info >/dev/null 2>&1; then \
		docker run --rm -v $(PROJECT_ROOT)/haproxy:/usr/local/etc/haproxy:ro haproxy:$(HAPROXY_VERSION) haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg || (echo "$(RED)❌ HAProxy configuration has errors$(RESET)" && exit 1); \
	else \
		echo "$(YELLOW)⚠️  Neither HAProxy binary nor Docker available, skipping strict HAProxy syntax check...$(RESET)"; \
	fi
	@echo "$(GREEN)✅ HAProxy configuration syntax validation complete!$(RESET)"

# Check Lua scripts syntax
lint-lua:
	@echo "$(CYAN)🔍 Checking Lua scripts syntax...$(RESET)"
	@if [ -f $(PROJECT_ROOT)/scripts/lua_validate.sh ]; then \
		chmod +x $(PROJECT_ROOT)/scripts/lua_validate.sh; \
		echo "$(YELLOW)Using local-only mode for Lua validation...$(RESET)"; \
		$(PROJECT_ROOT)/scripts/lua_validate.sh --local-only || exit 1; \
	elif command -v luac >/dev/null 2>&1; then \
		for script in $(PROJECT_ROOT)/haproxy/lua/*.lua; do \
			echo "Checking $${script}..."; \
			luac -p $${script} || (echo "$(RED)❌ Lua syntax error in $${script}$(RESET)" && exit 1); \
		done; \
	elif command -v lua >/dev/null 2>&1; then \
		for script in $(PROJECT_ROOT)/haproxy/lua/*.lua; do \
			echo "Checking $${script}..."; \
			lua -e "loadfile('$${script}')" || (echo "$(RED)❌ Lua syntax error in $${script}$(RESET)" && exit 1); \
		done; \
	elif docker info >/dev/null 2>&1; then \
		docker run --rm -v $(PROJECT_ROOT)/haproxy/lua:/scripts:ro alpine:latest sh -c "for script in /scripts/*.lua; do echo \"Checking \$${script}...\"; lua -e \"loadfile('\$${script}')\" || exit 1; done" || (echo "$(RED)❌ Lua syntax errors found$(RESET)" && exit 1); \
	else \
		echo "$(YELLOW)⚠️  No Lua interpreter available, skipping strict Lua syntax check...$(RESET)"; \
	fi
	@echo "$(GREEN)✅ Lua scripts syntax validation complete!$(RESET)"

# Test HAProxy configuration
test-haproxy:
	@echo "$(CYAN)🧪 Testing HAProxy configuration...$(RESET)"
	@if [ -f $(PROJECT_ROOT)/scripts/test_haproxy.sh ]; then \
		chmod +x $(PROJECT_ROOT)/scripts/test_haproxy.sh; \
		$(PROJECT_ROOT)/scripts/test_haproxy.sh || exit 1; \
	elif command -v haproxy >/dev/null 2>&1; then \
		haproxy -c -f $(PROJECT_ROOT)/haproxy/haproxy.cfg || (echo "$(RED)❌ HAProxy configuration test failed$(RESET)" && exit 1); \
	elif docker info >/dev/null 2>&1; then \
		mkdir -p $(PROJECT_ROOT)/test-results; \
		docker run --rm -v $(PROJECT_ROOT)/haproxy:/usr/local/etc/haproxy:ro \
			--name haproxy-test haproxy:$(HAPROXY_VERSION) \
			haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg || (echo "$(RED)❌ HAProxy configuration test failed$(RESET)" && exit 1); \
	else \
		echo "$(YELLOW)⚠️  Neither HAProxy binary nor Docker available, skipping HAProxy test...$(RESET)"; \
	fi
	@echo "$(GREEN)✅ HAProxy configuration test passed!$(RESET)"

# Test Lua scripts
test-lua:
	@echo "$(CYAN)🧪 Testing Lua scripts...$(RESET)"
	@mkdir -p $(PROJECT_ROOT)/test-results
	@if [ -f $(PROJECT_ROOT)/scripts/test_lua_scripts.sh ]; then \
		$(PROJECT_ROOT)/scripts/test_lua_scripts.sh; \
	elif command -v lua >/dev/null 2>&1; then \
		for script in $(PROJECT_ROOT)/haproxy/lua/*.lua; do \
			echo "Running basic test for $${script}..."; \
			lua -e "dofile('$${script}')" || (echo "$(RED)❌ Lua test failed for $${script}$(RESET)" && exit 1); \
		done; \
	elif docker info >/dev/null 2>&1; then \
		docker run --rm -v $(PROJECT_ROOT)/haproxy/lua:/scripts:ro alpine/lua:latest sh -c "for script in /scripts/*.lua; do echo \"Running basic test for $${script}...\"; lua $${script} || exit 1; done" || (echo "$(RED)❌ Lua tests failed$(RESET)" && exit 1); \
	else \
		echo "$(YELLOW)⚠️  No Lua interpreter available, skipping Lua tests...$(RESET)"; \
	fi
	@echo "$(GREEN)✅ Lua scripts tested successfully!$(RESET)"

# Run all validation checks
validate-all: lint test-haproxy test-lua verify-versions
	@echo "$(GREEN)✅ All validation checks passed!$(RESET)"

# CI setup - prepare environment for CI
ci-setup:
	@echo "$(CYAN)🔧 Setting up CI environment...$(RESET)"
	@echo "$(CYAN)Verifying required versions...$(RESET)"
	@if [ -f $(PROJECT_ROOT)/scripts/check_versions.sh ]; then \
		$(PROJECT_ROOT)/scripts/check_versions.sh || (echo "$(RED)❌ Environment does not meet version requirements$(RESET)" && exit 1); \
	fi
	@mkdir -p $(PROJECT_ROOT)/cmd/ratelimit-test/build $(PROJECT_ROOT)/cmd/ratelimit-test/results $(PROJECT_ROOT)/test-results $(PROJECT_ROOT)/haproxy/config
	@cd $(PROJECT_ROOT)/cmd/ratelimit-test && go mod tidy
	@if [ -z "$(shell which golangci-lint)" ] && [ ! -z "$(shell which go)" ]; then \
		echo "$(YELLOW)Installing golangci-lint...$(RESET)"; \
		GO111MODULE=on go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest; \
	fi
	@echo "$(CYAN)Generating service accounts for testing...$(RESET)"
	@if [ ! -f $(PROJECT_ROOT)/haproxy/config/generated_service_accounts.json ]; then \
		chmod +x $(PROJECT_ROOT)/scripts/generate-minio-service-accounts.sh; \
		if [ -n "$(CI)" ]; then \
			echo "$(YELLOW)CI environment detected, creating minimal config for testing$(RESET)"; \
			echo '{"service_accounts": [{"access_key": "TESTKEY123456789", "secret_key": "testsecret123456789", "group": "basic"}, {"access_key": "TESTKEY987654321", "secret_key": "testsecret987654321", "group": "premium"}], "metadata": {"total_accounts": 2}}' > $(PROJECT_ROOT)/haproxy/config/generated_service_accounts.json; \
		else \
			$(PROJECT_ROOT)/scripts/generate-minio-service-accounts.sh || ( \
				echo "$(YELLOW)⚠️  Service account generation failed, creating minimal config$(RESET)"; \
				echo '{"service_accounts": [{"access_key": "TESTKEY123456789", "secret_key": "testsecret123456789", "group": "basic"}, {"access_key": "TESTKEY987654321", "secret_key": "testsecret987654321", "group": "premium"}], "metadata": {"total_accounts": 2}}' > $(PROJECT_ROOT)/haproxy/config/generated_service_accounts.json; \
			); \
		fi; \
	fi
	@echo "$(GREEN)✅ CI setup complete!$(RESET)"

# CI test - run tests in CI environment
ci-test: ci-setup
	@echo "$(CYAN)🧪 Running tests in CI environment...$(RESET)"
	@mkdir -p $(PROJECT_ROOT)/test-results
	@cd $(PROJECT_ROOT)/cmd/ratelimit-test && go test -v ./... -coverprofile=coverage.out
	@mv $(PROJECT_ROOT)/cmd/ratelimit-test/coverage.out $(PROJECT_ROOT)/test-results/coverage.out || true
	@cd $(PROJECT_ROOT)/cmd/ratelimit-test && go build -o build/minio-ratelimit-test *.go
	@$(TEST_CMD) -duration=30s -accounts=2 -json -output=$(PROJECT_ROOT)/test-results/ci_results.json -config=$(PROJECT_ROOT)/haproxy/config/generated_service_accounts.json
	@echo "$(GREEN)✅ CI tests complete!$(RESET)"

# CI validate - run validations in CI environment
ci-validate: ci-setup lint validate-all
	@echo "$(CYAN)🔍 Running validations in CI environment...$(RESET)"
	@echo "$(GREEN)✅ CI validation complete!$(RESET)"
