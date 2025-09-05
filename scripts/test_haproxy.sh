#!/bin/bash
# HAProxy Configuration Testing Script
# A simplified version that just verifies basic functionality

# Colors for output - disable if not in terminal or if NO_COLOR is set
if [ -t 1 ] && [ -z "$NO_COLOR" ] && [ -z "$CI_NO_COLOR" ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  RESET='\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  RESET=''
fi

# Default paths
HAPROXY_CONFIG="./haproxy/haproxy.cfg"
TEST_OUTPUT="./test-results"

# Create output directory
mkdir -p "$TEST_OUTPUT"

echo "${BLUE}=== HAProxy Configuration Testing ===${RESET}"

# Check if config file exists
if [ ! -f "$HAPROXY_CONFIG" ]; then
  echo "${RED}❌ HAProxy configuration file not found: $HAPROXY_CONFIG${RESET}"
  exit 1
fi

# Check for required sections
echo "Checking for required sections..."
sections=("global" "defaults" "frontend" "backend")
missing=false

for section in "${sections[@]}"; do
  if ! grep -q "^$section" "$HAPROXY_CONFIG"; then
    echo "${RED}❌ Required section not found: $section${RESET}"
    missing=true
  fi
done

if [ "$missing" = true ]; then
  echo "${RED}❌ Some required HAProxy sections are missing!${RESET}"
  exit 1
fi

# Check for Lua script loading
echo "Checking for Lua script loading..."
if ! grep -q "lua-load" "$HAPROXY_CONFIG"; then
  echo "${YELLOW}⚠️  No lua-load directive found - Lua scripts might not be loaded${RESET}"
fi

# Check for rate limiting
echo "Checking for rate limiting configuration..."
if ! grep -q "stick-table" "$HAPROXY_CONFIG"; then
  echo "${YELLOW}⚠️  No stick-table found - rate limiting might not be properly configured${RESET}"
fi

# Check HAProxy server configuration
echo "Checking server configuration..."
if ! grep -q "server" "$HAPROXY_CONFIG"; then
  echo "${YELLOW}⚠️  No server configuration found in HAProxy config${RESET}"
else
  echo "${GREEN}✅ Server configuration found${RESET}"
fi

# Final verdict
echo "${GREEN}✅ HAProxy configuration tests completed!${RESET}"
exit 0
