#!/bin/bash
# Advanced HAProxy Configuration Testing Script

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Default values
HAPROXY_CONFIG="./haproxy/haproxy.cfg"
TEST_DIR="./haproxy/tests"
CONFIG_DIR="./haproxy/config"
TEST_OUTPUT="./test-results"

# Create directories if they don't exist
mkdir -p "$TEST_DIR"
mkdir -p "$TEST_OUTPUT"

# Function to check for the presence of required files
check_required_files() {
    echo "${BLUE}Checking for required files...${RESET}"

    # Check main config
    if [ ! -f "$HAPROXY_CONFIG" ]; then
        echo "${RED}❌ HAProxy configuration file not found: $HAPROXY_CONFIG${RESET}"
        exit 1
    fi

    # Check Lua scripts
    if [ ! -f "./haproxy/lua/extract_api_keys.lua" ]; then
        echo "${RED}❌ Lua script not found: ./haproxy/lua/extract_api_keys.lua${RESET}"
        exit 1
    fi

    if [ ! -f "./haproxy/lua/dynamic_rate_limiter.lua" ]; then
        echo "${RED}❌ Lua script not found: ./haproxy/lua/dynamic_rate_limiter.lua${RESET}"
        exit 1
    fi

    # Check config maps
    local missing=false
    for map_file in "api_key_groups.map" "rate_limits_per_minute.map" "rate_limits_per_second.map"; do
        if [ ! -f "$CONFIG_DIR/$map_file" ]; then
            echo "${YELLOW}⚠️  Map file not found: $CONFIG_DIR/$map_file${RESET}"
            missing=true
        fi
    done

    if [ "$missing" = true ]; then
        echo "${YELLOW}⚠️  Some map files are missing. Attempting to generate test tokens...${RESET}"
        if [ -f "./scripts/generate_test_tokens.sh" ]; then
            ./scripts/generate_test_tokens.sh
        else
            echo "${RED}❌ Cannot generate map files - script not found${RESET}"
            exit 1
        fi
    fi

    echo "${GREEN}✅ All required files are present!${RESET}"
}

# Function to validate HAProxy configuration syntax
validate_haproxy_syntax() {
    echo "${BLUE}Validating HAProxy configuration syntax...${RESET}"

    if command -v haproxy >/dev/null 2>&1; then
        echo "Using local HAProxy binary..."
        haproxy -c -f "$HAPROXY_CONFIG" > "$TEST_OUTPUT/haproxy_syntax.log" 2>&1
        if [ $? -ne 0 ]; then
            echo "${RED}❌ HAProxy configuration has syntax errors!${RESET}"
            cat "$TEST_OUTPUT/haproxy_syntax.log"
            exit 1
        fi
    elif docker info >/dev/null 2>&1; then
        echo "Using Docker for HAProxy validation..."
        docker run --rm -v "$(pwd)/haproxy:/usr/local/etc/haproxy:ro" haproxy:3.0 \
            haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg > "$TEST_OUTPUT/haproxy_syntax.log" 2>&1
        if [ $? -ne 0 ]; then
            echo "${RED}❌ HAProxy configuration has syntax errors!${RESET}"
            cat "$TEST_OUTPUT/haproxy_syntax.log"
            exit 1
        fi
    else
        echo "${YELLOW}⚠️  Neither HAProxy binary nor Docker available, skipping syntax validation...${RESET}"
        return
    fi

    echo "${GREEN}✅ HAProxy configuration syntax is valid!${RESET}"
}

# Function to check for required sections in HAProxy config
check_haproxy_sections() {
    echo "${BLUE}Checking HAProxy configuration for required sections...${RESET}"

    # Check for important sections
    local sections=("global" "defaults" "frontend" "backend")
    local missing=false

    for section in "${sections[@]}"; do
        if ! grep -q "^$section" "$HAPROXY_CONFIG"; then
            echo "${RED}❌ Required section not found: $section${RESET}"
            missing=true
        fi
    done

    # Check for stick-table (rate limiting)
    if ! grep -q "stick-table" "$HAPROXY_CONFIG"; then
        echo "${YELLOW}⚠️  No stick-table found - rate limiting might not be properly configured${RESET}"
    fi

    # Check for Lua script loading
    if ! grep -q "lua-load" "$HAPROXY_CONFIG"; then
        echo "${YELLOW}⚠️  No lua-load directive found - Lua scripts might not be loaded${RESET}"
    fi

    if [ "$missing" = true ]; then
        echo "${RED}❌ Some required HAProxy sections are missing!${RESET}"
        exit 1
    fi

    echo "${GREEN}✅ All required HAProxy sections are present!${RESET}"
}

# Function to check for rate limiting configuration
check_rate_limiting() {
    echo "${BLUE}Checking rate limiting configuration...${RESET}"

    # Check for rate limiting configurations
    if ! grep -q "http-request track-sc" "$HAPROXY_CONFIG"; then
        echo "${YELLOW}⚠️  No http-request track-sc directive found - rate limiting might not be active${RESET}"
    fi

    # Check for rate limiting actions
    if ! grep -q "http-request deny" "$HAPROXY_CONFIG" && ! grep -q "http-request tarpit" "$HAPROXY_CONFIG"; then
        echo "${YELLOW}⚠️  No deny/tarpit actions found - rate limiting might not be enforcing limits${RESET}"
    fi

    echo "${GREEN}✅ Rate limiting configuration check completed!${RESET}"
}

# Function to check Lua script integration
check_lua_integration() {
    echo "${BLUE}Checking Lua script integration...${RESET}"

    # Check for Lua script loading
    if ! grep -q "lua-load.*extract_api_keys.lua" "$HAPROXY_CONFIG"; then
        echo "${YELLOW}⚠️  extract_api_keys.lua not loaded in HAProxy config${RESET}"
    fi

    if ! grep -q "lua-load.*dynamic_rate_limiter.lua" "$HAPROXY_CONFIG"; then
        echo "${YELLOW}⚠️  dynamic_rate_limiter.lua not loaded in HAProxy config${RESET}"
    fi

    # Check for Lua function calls
    if ! grep -q "http-request.*lua\." "$HAPROXY_CONFIG"; then
        echo "${YELLOW}⚠️  No Lua function calls found in HTTP request processing${RESET}"
    fi

    echo "${GREEN}✅ Lua script integration check completed!${RESET}"
}

# Main function
main() {
    echo "${BLUE}=== HAProxy Advanced Configuration Testing ===${RESET}"

    # Run checks
    check_required_files
    validate_haproxy_syntax
    check_haproxy_sections
    check_rate_limiting
    check_lua_integration

    echo "${GREEN}✅ All HAProxy configuration tests passed!${RESET}"
}

# Run the script
main
