#!/bin/bash
# Comprehensive validation and testing of the MinIO Rate Limiting setup
# This script verifies that all validation tools and tests work correctly

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

# Define colors as strings for the print_styled function
RED="red"
GREEN="green"
YELLOW="yellow"
BLUE="blue"

print_styled "$BLUE" "=== MinIO Rate Limiting Verification Suite ==="
print_styled "$BLUE" "This script will test all validation tools and tests"

# Step 1: Check for required tools
print_styled "$BLUE" "Step 1: Checking for required tools..."

# Check for Go
if ! command -v go &> /dev/null; then
    print_styled "$RED" "❌ Go is not installed"
    print_styled "$YELLOW" "Please install Go 1.21 or higher"
    exit 1
else
    GO_VERSION=$(go version | awk '{print $3}')
    print_styled "$GREEN" "✅ Found $GO_VERSION"
fi

# Check for Docker
if ! command -v docker &> /dev/null; then
    print_styled "$YELLOW" "⚠️ Docker is not installed (optional but recommended)"
else
    DOCKER_VERSION=$(docker --version | awk '{print $3}')
    print_styled "$GREEN" "✅ Found Docker $DOCKER_VERSION"
fi

# Check for Docker Compose (v1 and v2)
DOCKER_COMPOSE_FOUND=false

# Check for Docker Compose v2 (Docker plugin)
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE_VERSION=$(docker compose version | head -n 1)
    print_styled "$GREEN" "✅ Found Docker Compose v2: $DOCKER_COMPOSE_VERSION"
    print_styled "$BLUE" "Command to use: docker compose"
    DOCKER_COMPOSE_CMD="docker compose"
    DOCKER_COMPOSE_FOUND=true
fi

# Check for Docker Compose v1 (standalone binary)
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_VERSION=$(docker-compose --version | awk '{print $3}' | tr -d ',')
    print_styled "$GREEN" "✅ Found Docker Compose v1: $DOCKER_COMPOSE_VERSION"
    print_styled "$BLUE" "Command to use: docker-compose"

    if [ "$DOCKER_COMPOSE_FOUND" = false ]; then
        DOCKER_COMPOSE_CMD="docker-compose"
        DOCKER_COMPOSE_FOUND=true
    else
        print_styled "$YELLOW" "⚠️ Both Docker Compose v1 and v2 are installed. Using v2 by default."
    fi
fi

# If no Docker Compose found
if [ "$DOCKER_COMPOSE_FOUND" = false ]; then
    print_styled "$YELLOW" "⚠️ Docker Compose is not installed (optional but recommended)"
    print_styled "$YELLOW" "Install with: sudo apt-get install docker-compose"
fi

# Step 2: Check for HAProxy and Lua
print_styled "$BLUE" "Step 2: Checking for HAProxy and Lua..."

# Check for HAProxy
if ! command -v haproxy &> /dev/null; then
    print_styled "$YELLOW" "⚠️ HAProxy is not installed locally (will use Docker fallback)"
else
    HAPROXY_VERSION=$(haproxy -v | head -n 1)
    print_styled "$GREEN" "✅ Found $HAPROXY_VERSION"
fi

# Check for Lua
if ! command -v lua &> /dev/null; then
    print_styled "$YELLOW" "⚠️ Lua is not installed locally (will use Docker fallback)"
else
    LUA_VERSION=$(lua -v)
    print_styled "$GREEN" "✅ Found $LUA_VERSION"
fi

# Step 3: Run make validate-all
print_styled "$BLUE" "Step 3: Running 'make validate-all'..."
make validate-all
if [ $? -ne 0 ]; then
    print_styled "$RED" "❌ 'make validate-all' failed"
    print_styled "$YELLOW" "Please check the error messages above"
    exit 1
else
    print_styled "$GREEN" "✅ 'make validate-all' succeeded"
fi

# Step 4: Run make validate-ratelimit
print_styled "$BLUE" "Step 4: Running 'make validate-ratelimit'..."
if ! make -n validate-ratelimit >/dev/null 2>&1; then
    print_styled "$YELLOW" "⚠️ The validate-ratelimit target seems to be missing dependencies"
    print_styled "$BLUE" "Checking individual components instead..."

    # Run the dependencies separately
    make lint-haproxy
    if [ $? -ne 0 ]; then
        print_styled "$RED" "❌ HAProxy validation failed"
        exit 1
    fi

    make lint-lua
    if [ $? -ne 0 ]; then
        print_styled "$RED" "❌ Lua validation failed"
        exit 1
    fi

    make ratelimit-test-build
    if [ $? -ne 0 ]; then
        print_styled "$RED" "❌ Building rate limiting test tool failed"
        exit 1
    fi

    print_styled "$GREEN" "✅ Rate limiting components validated successfully"
else
    # If the target exists, run it normally
    make validate-ratelimit
    if [ $? -ne 0 ]; then
        print_styled "$RED" "❌ 'make validate-ratelimit' failed"
        print_styled "$YELLOW" "Please check the error messages above"
        exit 1
    else
        print_styled "$GREEN" "✅ 'make validate-ratelimit' succeeded"
    fi
fi

# Step 5: Build rate limit test tool
print_styled "$BLUE" "Step 5: Building rate limit test tool..."
make ratelimit-test-build
if [ $? -ne 0 ]; then
    print_styled "$RED" "❌ Building rate limit test tool failed"
    print_styled "$YELLOW" "Please check the error messages above"
    exit 1
else
    print_styled "$GREEN" "✅ Rate limit test tool built successfully"
fi

# Step 6: Generate test tokens
print_styled "$BLUE" "Step 6: Generating test tokens..."
make ratelimit-tokens
if [ $? -ne 0 ]; then
    print_styled "$RED" "❌ Generating test tokens failed"
    print_styled "$YELLOW" "Please check the error messages above"
    exit 1
else
    print_styled "$GREEN" "✅ Test tokens generated successfully"
fi

# Determine best Docker Compose command for success message
if [ -z "$DOCKER_COMPOSE_CMD" ]; then
    if docker compose version >/dev/null 2>&1; then
        DC_CMD="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        DC_CMD="docker-compose"
    else
        DC_CMD="docker compose or docker-compose"
    fi
else
    DC_CMD="$DOCKER_COMPOSE_CMD"
fi

# Success message
print_styled "$GREEN" "=== ALL VERIFICATION TESTS COMPLETED SUCCESSFULLY ==="
print_styled "$BLUE" "Your MinIO rate limiting setup has been verified and all tools are working correctly."
print_styled "$BLUE" "Next steps:"
print_styled "$BLUE" "1. Start the stack: '$DC_CMD up' or 'make up'"

print_styled "$BLUE" "2. Run comprehensive tests: 'make test-all-tiers'"
print_styled "$BLUE" "3. Try different testing scenarios with 'make test-basic', 'make test-premium', etc."

exit 0
