#!/bin/bash
# HAProxy Configuration Testing Script
# A simplified version that just verifies basic functionality

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
TEST_OUTPUT="./test-results"

# Create output directory
mkdir -p "$TEST_OUTPUT"

print_styled "$BLUE" "=== HAProxy Configuration Testing ==="

# Check if config file exists
if [ ! -f "$HAPROXY_CONFIG" ]; then
  print_styled "$RED" "❌ HAProxy configuration file not found: $HAPROXY_CONFIG"
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
  print_styled "$GREEN" "✅ Server configuration found"
fi

# Final verdict
print_styled "$GREEN" "✅ HAProxy configuration tests completed!"
exit 0
