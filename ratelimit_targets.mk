# Rate limiting test targets

# Define paths used for validation
HAPROXY_CONFIG ?= ./haproxy/haproxy.cfg
LUA_DIR ?= ./haproxy/lua

# Check for required files for rate limiting
define check_rate_limiting_files
	@echo "Checking for required rate limiting files..."
	@if [ ! -f "$(HAPROXY_CONFIG)" ]; then \
		echo "$(RED)❌ HAProxy configuration file not found: $(HAPROXY_CONFIG)$(RESET)"; \
		exit 1; \
	else \
		echo "$(GREEN)✅ HAProxy configuration file found$(RESET)"; \
	fi
	@if [ ! -d "$(LUA_DIR)" ] || [ -z "$$(find $(LUA_DIR) -name "*.lua" 2>/dev/null)" ]; then \
		echo "$(RED)❌ Lua scripts not found in: $(LUA_DIR)$(RESET)"; \
		exit 1; \
	else \
		echo "$(GREEN)✅ Lua scripts found$(RESET)"; \
	fi
endef

# Check for rate limiting configuration in HAProxy config
define check_rate_limiting_config
	@echo "Checking rate limiting configuration..."
	@if grep -q "stick-table" "$(HAPROXY_CONFIG)" && grep -q "lua-load" "$(HAPROXY_CONFIG)"; then \
		echo "$(GREEN)✅ Rate limiting configuration found$(RESET)"; \
	else \
		echo "$(RED)❌ Rate limiting configuration might be missing in HAProxy config$(RESET)"; \
		exit 1; \
	fi
endef

# Build the rate limit test tool
ratelimit-test-build:
	@$(call print_styled,$(BLUE),"Building rate limit testing tool...")
	@mkdir -p cmd/ratelimit-test/build
	@go build -o cmd/ratelimit-test/build/minio-ratelimit-test ./cmd/ratelimit-test
	@$(call print_styled,$(GREEN),"✅ Rate limit testing tool built successfully")

# Generate test tokens for rate limiting
ratelimit-tokens:
	@$(call print_styled,$(BLUE),"Generating test tokens for rate limiting...")
	@mkdir -p haproxy/config
	@./scripts/generate_test_tokens.sh
	@$(call print_styled,$(GREEN),"✅ Test tokens generated successfully")

# Validate complete rate limiting setup
validate-ratelimit: lint-haproxy lint-lua ratelimit-test-build ratelimit-tokens
	@$(call print_styled,$(BLUE),"=== Validating complete rate limiting setup ===")
	@$(call check_rate_limiting_files)
	@$(call check_rate_limiting_config)
	@$(call print_styled,$(GREEN),"✅ Rate limiting setup validated successfully!")
	@$(call print_styled,$(BLUE),"Next steps:")
	@$(call print_styled,$(BLUE),"1. Start the stack: '$(DOCKER_COMPOSE_CMD) up' or 'make up'")
	@$(call print_styled,$(BLUE),"2. Test the rate limiting: './cmd/ratelimit-test/build/minio-ratelimit-test'")

# Run the rate limiting tests (after starting the stack)
ratelimit-test: ratelimit-test-build
	@$(call print_styled,$(BLUE),"Running rate limiting tests...")
	@./cmd/ratelimit-test/build/minio-ratelimit-test

# Run all targets for comprehensive testing
test-all: lint validate-all validate-ratelimit ratelimit-test-build
	@$(call print_styled,$(GREEN),"✅ All validations and tests completed successfully!")
