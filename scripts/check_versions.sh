#!/bin/bash
# CI Environment Version Validator
# This script checks if all required tools are available with the correct versions

# Initialize variables
warnings=0
exit_code=0

# Load versions from versions.mk
if [ -f ./versions.mk ]; then
  source <(grep -E '^GO_VERSION|^LUA_VERSION|^HAPROXY_VERSION|^DOCKER_COMPOSE_VERSION|^DOCKER_MINIMUM_VERSION' ./versions.mk | sed 's/ := /=/g')
fi

# Set defaults if not loaded from versions.mk
GO_VERSION=${GO_VERSION:-1.24}
LUA_VERSION=${LUA_VERSION:-5.3}
HAPROXY_VERSION=${HAPROXY_VERSION:-3.0}
DOCKER_COMPOSE_VERSION=${DOCKER_COMPOSE_VERSION:-2.26.0}
DOCKER_MINIMUM_VERSION=${DOCKER_MINIMUM_VERSION:-20.10.0}

# Colors for output
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
RESET="\033[0m"

# Disable colors in CI
if [ -n "$CI" ] || [ -n "$CI_NO_COLOR" ]; then
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  RESET=""
fi

# Helper for printing
print_status() {
  local status=$1
  local message=$2

  if [ "$status" = "OK" ]; then
    echo -e "${GREEN}✅ ${message}${RESET}"
  elif [ "$status" = "WARNING" ]; then
    echo -e "${YELLOW}⚠️  ${message}${RESET}"
  elif [ "$status" = "ERROR" ]; then
    echo -e "${RED}❌ ${message}${RESET}"
  else
    echo -e "${BLUE}ℹ️  ${message}${RESET}"
  fi
}

echo -e "${BLUE}=== CI Environment Version Check ===${RESET}"
echo "Required versions:"
echo "- Go: $GO_VERSION+"
echo "- Lua: $LUA_VERSION+"
echo "- HAProxy: $HAPROXY_VERSION+"
echo "- Docker: $DOCKER_MINIMUM_VERSION+"
echo "- Docker Compose: $DOCKER_COMPOSE_VERSION+"
echo ""

# Check Go version
echo "Checking Go..."
if command -v go >/dev/null 2>&1; then
  current_go_version=$(go version | awk '{print $3}' | sed 's/go//g')
  echo "Installed: $current_go_version"

  # Simple version check (just major.minor)
  required_major=$(echo $GO_VERSION | cut -d. -f1)
  required_minor=$(echo $GO_VERSION | cut -d. -f2)
  current_major=$(echo $current_go_version | cut -d. -f1)
  current_minor=$(echo $current_go_version | cut -d. -f2)

  if [ "$current_major" -gt "$required_major" ] || ([ "$current_major" -eq "$required_major" ] && [ "$current_minor" -ge "$required_minor" ]); then
    print_status "OK" "Go version is sufficient"
  else
    print_status "ERROR" "Go version $current_go_version is below required $GO_VERSION"
    exit_code=1
  fi
else
  print_status "ERROR" "Go is not installed"
  exit_code=1
fi

# Check Lua version
echo -e "\nChecking Lua..."
if command -v lua >/dev/null 2>&1; then
  current_lua_version=$(lua -v | awk '{print $2}')
  echo "Installed: $current_lua_version"

  required_lua_major=$(echo $LUA_VERSION | cut -d. -f1)
  required_lua_minor=$(echo $LUA_VERSION | cut -d. -f2)
  current_lua_major=$(echo $current_lua_version | cut -d. -f1)
  current_lua_minor=$(echo $current_lua_version | cut -d. -f2)

  if [ "$current_lua_major" -gt "$required_lua_major" ] || ([ "$current_lua_major" -eq "$required_lua_major" ] && [ "$current_lua_minor" -ge "$required_lua_minor" ]); then
    print_status "OK" "Lua version is sufficient"
  else
    print_status "WARNING" "Lua version $current_lua_version is below required $LUA_VERSION (will use Docker fallback)"
    warnings=$((warnings + 1))
  fi
else
  print_status "WARNING" "Lua is not installed (will use Docker fallback)"
  warnings=$((warnings + 1))
fi

# Check HAProxy version
echo -e "\nChecking HAProxy..."
if command -v haproxy >/dev/null 2>&1; then
  current_haproxy_version=$(haproxy -v | head -n1 | awk '{print $3}')
  echo "Installed: $current_haproxy_version"

  required_haproxy_major=$(echo $HAPROXY_VERSION | cut -d. -f1)
  required_haproxy_minor=$(echo $HAPROXY_VERSION | cut -d. -f2)
  current_haproxy_major=$(echo $current_haproxy_version | cut -d. -f1)
  current_haproxy_minor=$(echo $current_haproxy_version | cut -d. -f2)

  if [ "$current_haproxy_major" -gt "$required_haproxy_major" ] || ([ "$current_haproxy_major" -eq "$required_haproxy_major" ] && [ "$current_haproxy_minor" -ge "$required_haproxy_minor" ]); then
    print_status "OK" "HAProxy version is sufficient"
  else
    print_status "WARNING" "HAProxy version $current_haproxy_version is below required $HAPROXY_VERSION (will use Docker fallback)"
    warnings=$((warnings + 1))
  fi
else
  print_status "WARNING" "HAProxy is not installed (will use Docker fallback)"
  warnings=$((warnings + 1))
fi

# Check Docker version
echo -e "\nChecking Docker..."
if command -v docker >/dev/null 2>&1; then
  current_docker_version=$(docker --version | awk '{print $3}' | sed 's/,//g')
  echo "Installed: $current_docker_version"

  if [ $(printf '%s\n' "$DOCKER_MINIMUM_VERSION" "$current_docker_version" | sort -V | head -n1) = "$DOCKER_MINIMUM_VERSION" ]; then
    print_status "OK" "Docker version is sufficient"
  else
    print_status "ERROR" "Docker version $current_docker_version is below required $DOCKER_MINIMUM_VERSION"
    exit_code=1
  fi
else
  print_status "ERROR" "Docker is not installed"
  exit_code=1
fi

# Check Docker Compose version
echo -e "\nChecking Docker Compose..."
if docker compose version >/dev/null 2>&1; then
  current_compose_version=$(docker compose version | awk '{print $4}')
  compose_type="v2"
  echo "Installed: $current_compose_version (v2)"
  print_status "OK" "Using Docker Compose v2 (embedded plugin)"
elif command -v docker-compose >/dev/null 2>&1; then
  current_compose_version=$(docker-compose --version | awk '{print $3}' | sed 's/,//g')
  compose_type="v1"
  echo "Installed: $current_compose_version (v1)"
  print_status "WARNING" "Using Docker Compose v1 (standalone binary) - v2 is recommended"
  warnings=$((warnings + 1))
else
  print_status "ERROR" "Docker Compose is not installed"
  exit_code=1
fi

echo -e "\n${BLUE}=== Environment Summary ===${RESET}"
if [ "$exit_code" -eq 1 ]; then
  print_status "ERROR" "One or more required tools are missing or have insufficient versions"
  echo "Please install the required tools or use Docker to run in containerized mode."
  exit 1
else
  print_status "OK" "Environment meets all essential requirements"
  if [ "$warnings" -gt 0 ]; then
    echo "Some non-critical warnings were found. Docker fallback will be used where needed."
  fi
  exit 0
fi
