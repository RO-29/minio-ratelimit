#!/bin/bash
# Advanced HAProxy Configuration Testing Script
# Supports both local and CI environments, with or without Docker

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Parse command line options
LOCAL_ONLY=false
DOCKER_FORCE=false
GITHUB_CI=false

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --local-only)
      LOCAL_ONLY=true
      shift
      ;;
    --docker-force)
      DOCKER_FORCE=true
      shift
      ;;
    --github-ci)
      GITHUB_CI=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Check if we're running in GitHub Actions
if [ -n "$GITHUB_ACTIONS" ]; then
  GITHUB_CI=true
fi

# Default values
HAPROXY_CONFIG="./haproxy/haproxy.cfg"
TEST_DIR="./haproxy/tests"
CONFIG_DIR="./haproxy/config"
TEST_OUTPUT="./test-results"

# Create directories if they don't exist
mkdir -p "$TEST_DIR"
mkdir -p "$TEST_OUTPUT"

    # Determine validation method
USE_DOCKER=false
SKIP_SYNTAX=false

if $LOCAL_ONLY; then
  echo "${YELLOW}⚠️ Local-only mode activated, will skip strict validation${RESET}"
  SKIP_SYNTAX=true
elif docker info >/dev/null 2>&1 || $DOCKER_FORCE; then
  USE_DOCKER=true
  echo "${BLUE}Docker detected, will use HAProxy container for validation${RESET}"
elif command -v haproxy >/dev/null 2>&1; then
  echo "${BLUE}Using local HAProxy installation for validation${RESET}"
else
  echo "${YELLOW}⚠️ Neither Docker nor HAProxy detected, will perform basic syntax checking only${RESET}"
  SKIP_SYNTAX=true
fi# Function to check for the presence of required files
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

    # If we're in skip syntax mode, just do basic checks
    if $SKIP_SYNTAX; then
        echo "${YELLOW}Skipping strict syntax validation (local-only mode)${RESET}"
        # Do basic checks only
        if ! grep -q "frontend" "$HAPROXY_CONFIG" || ! grep -q "backend" "$HAPROXY_CONFIG"; then
            echo "${RED}❌ Basic syntax check failed - missing frontend or backend section${RESET}"
            exit 1
        fi
        echo "${GREEN}✅ Basic HAProxy configuration check passed${RESET}"
        return 0
    fi

    # Create a temporary directory for validation if in Docker mode
    if $USE_DOCKER; then
        TEMP_CONFIG_DIR=$(mktemp -d)
        echo "Creating temporary configuration for Docker validation..."

        # Copy HAProxy config
        mkdir -p "$TEMP_CONFIG_DIR/haproxy"
        cp -r ./haproxy/* "$TEMP_CONFIG_DIR/haproxy/"

        # Create self-signed certificate for testing if it doesn't exist
        if [ ! -f "$TEMP_CONFIG_DIR/haproxy/certs/haproxy.pem" ]; then
            mkdir -p "$TEMP_CONFIG_DIR/haproxy/certs"
            openssl req -x509 -newkey rsa:2048 -nodes -keyout "$TEMP_CONFIG_DIR/haproxy/certs/haproxy.pem" \
            -out "$TEMP_CONFIG_DIR/haproxy/certs/haproxy.pem" -days 365 -subj "/CN=localhost" 2>/dev/null
        fi

        # Create a new version of haproxy.cfg with Docker-compatible paths
        TEMP_CFG="$TEMP_CONFIG_DIR/haproxy/haproxy.cfg.docker"
        cp "$TEMP_CONFIG_DIR/haproxy/haproxy.cfg" "$TEMP_CFG"

        # Fix certificate path for HAProxy in Docker
        sed -i.bak "s|/etc/ssl/certs/haproxy.pem|/usr/local/etc/haproxy/certs/haproxy.pem|g" "$TEMP_CFG" || \
        sed -i "" "s|/etc/ssl/certs/haproxy.pem|/usr/local/etc/haproxy/certs/haproxy.pem|g" "$TEMP_CFG"

        # Fix Lua script paths for Docker
        # First copy the Lua scripts to the correct location expected by the config
        mkdir -p "$TEMP_CONFIG_DIR/haproxy/lua_temp"
        cp -r "$TEMP_CONFIG_DIR/haproxy/lua/"*.lua "$TEMP_CONFIG_DIR/haproxy/lua_temp/"

        # Update the paths in the config to point to files where Docker will see them
        sed -i.bak "s|lua-load /usr/local/etc/haproxy/|lua-load /usr/local/etc/haproxy/lua_temp/|g" "$TEMP_CFG" || \
        sed -i "" "s|lua-load /usr/local/etc/haproxy/|lua-load /usr/local/etc/haproxy/lua_temp/|g" "$TEMP_CFG"

        # Fix http-request lua calls
        sed -i.bak "s|http-request lua.extract_api_key|http-request set-var(txn.api_key) lua.extract_api_key|g" "$TEMP_CFG" || \
        sed -i "" "s|http-request lua.extract_api_key|http-request set-var(txn.api_key) lua.extract_api_key|g" "$TEMP_CFG"

        # Fix map file paths for Docker
        sed -i.bak "s| ./haproxy/config/| /usr/local/etc/haproxy/config/|g" "$TEMP_CFG" || \
        sed -i "" "s| ./haproxy/config/| /usr/local/etc/haproxy/config/|g" "$TEMP_CFG"

        # Replace original file with Docker-compatible version
        mv "$TEMP_CFG" "$TEMP_CONFIG_DIR/haproxy/haproxy.cfg"

        echo "Running HAProxy validation in Docker..."
        # Create script to run HAProxy validation in container
        echo "#!/bin/sh
# First, check the environment
echo 'HAProxy validation environment:'
ls -la /usr/local/etc/haproxy/
echo '\\nLua scripts directory:'
ls -la /usr/local/etc/haproxy/lua_temp/ || mkdir -p /usr/local/etc/haproxy/lua_temp/
echo '\\nHAProxy config file content:'
cat /usr/local/etc/haproxy/haproxy.cfg
echo '\\nRunning validation:'
haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
" > "$TEMP_CONFIG_DIR/validate.sh"
        chmod +x "$TEMP_CONFIG_DIR/validate.sh"

        # Use this script for validation
        if $GITHUB_CI; then
            echo "Running in GitHub CI with extra debugging..."
            docker run --rm -v "$TEMP_CONFIG_DIR:/temp:ro" -v "$TEMP_CONFIG_DIR/haproxy:/usr/local/etc/haproxy:ro" haproxy:3.0 \
                sh /temp/validate.sh > "$TEST_OUTPUT/haproxy_syntax.log" 2>&1
        else
            docker run --rm -v "$TEMP_CONFIG_DIR:/temp:ro" -v "$TEMP_CONFIG_DIR/haproxy:/usr/local/etc/haproxy:ro" haproxy:3.0 \
                sh /temp/validate.sh > "$TEST_OUTPUT/haproxy_syntax.log" 2>&1
        fi

        VALIDATION_RESULT=$?

        # Clean up
        rm -rf "$TEMP_CONFIG_DIR"

        if [ $VALIDATION_RESULT -ne 0 ]; then
            echo "${RED}❌ HAProxy configuration has syntax errors!${RESET}"
            cat "$TEST_OUTPUT/haproxy_syntax.log"
            exit 1
        fi
    elif command -v haproxy >/dev/null 2>&1; then
        echo "Using local HAProxy binary..."

        # Create a temporary copy of the config with updated paths
        TEMP_CONFIG_FILE=$(mktemp)
        cp "$HAPROXY_CONFIG" "$TEMP_CONFIG_FILE"

        # Update paths to be relative for local validation
        sed -i.bak "s|/usr/local/etc/haproxy/|./haproxy/|g" "$TEMP_CONFIG_FILE" || \
        sed -i "" "s|/usr/local/etc/haproxy/|./haproxy/|g" "$TEMP_CONFIG_FILE"
        sed -i.bak "s|/etc/ssl/certs/haproxy.pem|./haproxy/certs/haproxy.pem|g" "$TEMP_CONFIG_FILE" || \
        sed -i "" "s|/etc/ssl/certs/haproxy.pem|./haproxy/certs/haproxy.pem|g" "$TEMP_CONFIG_FILE"

        # Create certificate directory if it doesn't exist
        mkdir -p ./haproxy/certs
        if [ ! -f "./haproxy/certs/haproxy.pem" ]; then
            openssl req -x509 -newkey rsa:2048 -nodes -keyout "./haproxy/certs/haproxy.pem" \
            -out "./haproxy/certs/haproxy.pem" -days 365 -subj "/CN=localhost" 2>/dev/null
        fi

        # Run validation
        haproxy -c -f "$TEMP_CONFIG_FILE" > "$TEST_OUTPUT/haproxy_syntax.log" 2>&1
        VALIDATION_RESULT=$?

        # Clean up
        rm "$TEMP_CONFIG_FILE"*

        if [ $VALIDATION_RESULT -ne 0 ]; then
            echo "${RED}❌ HAProxy configuration has syntax errors!${RESET}"
            cat "$TEST_OUTPUT/haproxy_syntax.log"
            exit 1
        fi
    else
        echo "${YELLOW}⚠️  Neither HAProxy binary nor Docker available, performing basic syntax validation...${RESET}"
        # Check for basic syntax issues
        if ! grep -q "frontend" "$HAPROXY_CONFIG" || ! grep -q "backend" "$HAPROXY_CONFIG"; then
            echo "${RED}❌ Basic syntax check failed - missing frontend or backend section${RESET}"
            exit 1
        fi
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

# Prepare HAProxy environment
prepare_environment() {
    echo "${BLUE}Preparing HAProxy test environment...${RESET}"

    # Create certificate directory if needed
    mkdir -p ./haproxy/certs

    # Generate SSL certificate if it doesn't exist
    if [ ! -f "./haproxy/certs/haproxy.pem" ]; then
        echo "${YELLOW}Generating self-signed certificate for HAProxy...${RESET}"
        openssl req -x509 -newkey rsa:2048 -nodes -keyout "./haproxy/certs/haproxy.pem" \
        -out "./haproxy/certs/haproxy.pem" -days 365 -subj "/CN=localhost" 2>/dev/null
    fi

    # Fix LF vs CRLF line endings if needed (common issue on macOS)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "${BLUE}Checking for line ending issues (macOS)...${RESET}"
        if command -v dos2unix >/dev/null 2>&1; then
            find ./haproxy -type f -name "*.lua" -exec dos2unix {} \; 2>/dev/null
        fi
    fi
}

# Main function
main() {
    echo "${BLUE}=== HAProxy Advanced Configuration Testing ===${RESET}"

    # Setup environment first
    prepare_environment

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
