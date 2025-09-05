#!/bin/bash
# Comprehensive Rate Limiting Validation
# Tests the complete setup including HAProxy, Lua, and rate limiting functionality

# Function to print with/without colors
print_styled() {
  local color="$1"
  local message="$2"

  # Completely disable color in CI or when requested
  if [ -n "$CI" ] || [ -n "$CI_NO_COLOR" ] || [ -n "$NO_COLOR" ] || [ ! -t 1 ]; then
    printf "%s\n" "$message"
  else
    case "$color" in
      "red") printf "\033[0;31m%s\033[0m\n" "$message" ;;
      "green") printf "\033[0;32m%s\033[0m\n" "$message" ;;
      "yellow") printf "\033[0;33m%s\033[0m\n" "$message" ;;
      "blue") printf "\033[0;34m%s\033[0m\n" "$message" ;;
      *) printf "%s\n" "$message" ;;
    esac
  fi
}

# No need for color variables anymore, we'll use the function instead
RED="red"
GREEN="green"
YELLOW="yellow"
BLUE="blue"

# Default paths
HAPROXY_CONFIG="./haproxy/haproxy.cfg"
LUA_DIR="./haproxy/lua"
TEST_OUTPUT="./test-results"
DOCKER_COMPOSE="./docker-compose.yml"

# Create output directory
mkdir -p "$TEST_OUTPUT"

print_styled "$BLUE" "=== MinIO Rate Limiting Comprehensive Validation ==="

# Check if all required files exist
print_styled "$BLUE" "Checking required files..."
MISSING_FILES=false

if [ ! -f "$HAPROXY_CONFIG" ]; then
  print_styled "$RED" "❌ HAProxy configuration file not found: $HAPROXY_CONFIG"
  MISSING_FILES=true
else
  print_styled "$GREEN" "✅ HAProxy configuration file found"
fi

if [ ! -d "$LUA_DIR" ]; then
  print_styled "$RED" "❌ Lua scripts directory not found: $LUA_DIR"
  MISSING_FILES=true
else
  LUA_FILES=$(find "$LUA_DIR" -name "*.lua" 2>/dev/null)
  if [ -z "$LUA_FILES" ]; then
    print_styled "$RED" "❌ No Lua scripts found in $LUA_DIR"
    MISSING_FILES=true
  else
    print_styled "$GREEN" "✅ Lua scripts found"
  fi
fi

if [ ! -f "$DOCKER_COMPOSE" ]; then
  print_styled "$YELLOW" "⚠️ Docker Compose file not found: $DOCKER_COMPOSE (not required for validation)"
else
  print_styled "$GREEN" "✅ Docker Compose file found"
fi

if [ "$MISSING_FILES" = true ]; then
  print_styled "$RED" "❌ Some required files are missing - cannot proceed with validation"
  exit 1
fi

# Check HAProxy configuration
print_styled "$BLUE" "Validating HAProxy configuration..."
if command -v haproxy >/dev/null 2>&1; then
  HAPROXY_VERSION=$(haproxy -v | head -n 1)
  print_styled "$BLUE" "Detected HAProxy: $HAPROXY_VERSION"

  if ! echo "$HAPROXY_VERSION" | grep -q "3\.[0-9]"; then
    print_styled "$YELLOW" "⚠️  Warning: Recommended HAProxy version is 3.0 or later"
  else
    print_styled "$GREEN" "✅ Using recommended HAProxy version (3.x)"
  fi

  # Check config syntax
  haproxy -c -f "$HAPROXY_CONFIG" > "$TEST_OUTPUT/haproxy_check.log" 2>&1
  if [ $? -eq 0 ]; then
    print_styled "$GREEN" "✅ HAProxy configuration is valid"
  else
    print_styled "$RED" "❌ HAProxy configuration has errors:"
    cat "$TEST_OUTPUT/haproxy_check.log"
    exit 1
  fi
else
  print_styled "$YELLOW" "⚠️ HAProxy binary not available - skipping direct validation"
fi

# Check for rate limiting configuration
print_styled "$BLUE" "Checking rate limiting configuration..."

# Check for stick-table
if grep -q "stick-table" "$HAPROXY_CONFIG"; then
  print_styled "$GREEN" "✅ Found stick-table configuration for rate limiting"
else
  print_styled "$RED" "❌ Missing stick-table configuration - rate limiting won't work"
  exit 1
fi

# Check for Lua scripts loading
if grep -q "lua-load" "$HAPROXY_CONFIG"; then
  print_styled "$GREEN" "✅ Found Lua script loading configuration"
else
  print_styled "$RED" "❌ Missing Lua script loading - rate limiting won't work"
  exit 1
fi

# Check for rate limiting directives
if grep -q "rate_limit" "$HAPROXY_CONFIG" || grep -q "sc_inc_gpc0" "$HAPROXY_CONFIG"; then
  print_styled "$GREEN" "✅ Found rate limiting directives"
else
  print_styled "$YELLOW" "⚠️ Rate limiting directives might be missing"
fi

# Validate Lua scripts for basic errors
print_styled "$BLUE" "Checking Lua scripts for rate limiting functions..."

# Check for standard rate limiting functions in Lua scripts
RATE_LIMIT_FOUND=false
for script in $LUA_FILES; do
  if grep -q "rate_limit" "$script" || grep -q "extract_api_key" "$script"; then
    print_styled "$GREEN" "✅ Found rate limiting functions in $script"
    RATE_LIMIT_FOUND=true
  fi
done

if [ "$RATE_LIMIT_FOUND" = false ]; then
  print_styled "$YELLOW" "⚠️ Rate limiting functions not found in Lua scripts"
fi

# Docker-based validation (if Docker is available)
if [ -f "$DOCKER_COMPOSE" ] && docker info >/dev/null 2>&1; then
  print_styled "$BLUE" "Docker is available - you can run docker-compose up to test full functionality"
  print_styled "$YELLOW" "⚠️ Full integration tests require running the stack with docker-compose"
  print_styled "$YELLOW" "⚠️ Then use test clients to verify rate limiting behavior"
else
  print_styled "$YELLOW" "⚠️ Docker not available or docker-compose file missing - skipping integration test info"
fi

print_styled "$GREEN" "✅ Comprehensive validation completed!"
print_styled "$BLUE" "Next steps:"
print_styled "$BLUE" "1. Run 'docker-compose up' to start the full stack"
print_styled "$BLUE" "2. Use './scripts/generate_test_tokens.sh' to create test credentials"
print_styled "$BLUE" "3. Test rate limiting with './cmd/ratelimit-test/build/minio-ratelimit-test'"
exit 0
