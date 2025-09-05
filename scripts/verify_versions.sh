#!/bin/bash
# verify_versions.sh - Verify version consistency across the project
#
# This script checks that all versions in the project are consistent with
# the centralized versions defined in versions.mk.

set -e

# Source the versions file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/export_versions.sh"

echo "🔍 Verifying versions across the project..."
echo "======================================"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Track issues
ISSUES_FOUND=0

# Function to report an issue
report_issue() {
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
  echo -e "${RED}❌ $1${NC}"
}

# Function to report success
report_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

# Function to report warning
report_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

echo "Checking Go version consistency..."

# Check go.mod files
while IFS= read -r -d '' file; do
  go_version=$(grep -E '^go ' "$file" | awk '{print $2}')
  if [[ "$go_version" != "$GO_VERSION" ]]; then
    report_issue "Go version mismatch in $file: found $go_version, expected $GO_VERSION"
  else
    report_success "Go version in $file matches versions.mk: $GO_VERSION"
  fi
done < <(find "$PROJECT_ROOT" -name "go.mod" -print0)

echo -e "\nChecking Docker image references..."

  # Check HAProxy version in Docker files
  while IFS= read -r file; do
    # Skip .bin directory
    if [[ "$file" == *".bin/"* ]]; then
      continue
    fi
    
    if grep -q "haproxy:" "$file"; then
      # Check for variable references like ${HAPROXY_VERSION} or $HAPROXY_VERSION
      # Also check for variable references with default values like ${HAPROXY_VERSION:-3.0}
      if grep -q "haproxy:\${HAPROXY_VERSION}" "$file" || \
         grep -q "haproxy:\$HAPROXY_VERSION" "$file" || \
         grep -q "haproxy:$HAPROXY_VERSION" "$file" || \
         grep -q "haproxy:\${HAPROXY_VERSION:-$HAPROXY_VERSION}" "$file"; then
        report_success "HAProxy version in $file uses version variable or matches versions.mk: $HAPROXY_VERSION"
      else
        used_version=$(grep -o "haproxy:[^ ]*" "$file" | head -1 | cut -d':' -f2)
        # Special case for docker-compose variables with default values
        if grep -q "haproxy:\${HAPROXY_VERSION:-" "$file"; then
          default_version=$(grep -o "\${HAPROXY_VERSION:-[^}]*" "$file" | sed 's/\${HAPROXY_VERSION:-//g')
          if [[ "$default_version" == "$HAPROXY_VERSION" ]]; then
            report_success "HAProxy version in $file uses correct default value: $HAPROXY_VERSION"
          else
            report_issue "HAProxy version default mismatch in $file: found default $default_version, expected $HAPROXY_VERSION"
          fi
        else
          report_issue "HAProxy version mismatch in $file: found $used_version, expected $HAPROXY_VERSION or variable reference"
        fi
      fi
    fi
  done < <(find "$PROJECT_ROOT" -type f -name "*.yml" -o -name "Dockerfile" | grep -v "versions.mk")

  # Check MinIO version
  while IFS= read -r file; do
    if grep -q "minio:" "$file"; then
      # Check for variable references like ${MINIO_VERSION} or $MINIO_VERSION
      # Also check for variable references with default values like ${MINIO_VERSION:-RELEASE.2025-04-22T22-12-26Z}
      if grep -q "minio:\${MINIO_VERSION}" "$file" || \
         grep -q "minio:\$MINIO_VERSION" "$file" || \
         grep -q "minio:$MINIO_VERSION" "$file" || \
         grep -q "minio:\${MINIO_VERSION:-$MINIO_VERSION}" "$file"; then
        report_success "MinIO version in $file uses version variable or matches versions.mk: $MINIO_VERSION"
      else
        used_version=$(grep -o "minio:[^ ]*" "$file" | head -1 | cut -d':' -f2)
        # Special case for docker-compose variables with default values
        if grep -q "minio:\${MINIO_VERSION:-" "$file"; then
          default_version=$(grep -o "\${MINIO_VERSION:-[^}]*" "$file" | sed 's/\${MINIO_VERSION:-//g')
          if [[ "$default_version" == "$MINIO_VERSION" ]]; then
            report_success "MinIO version in $file uses correct default value: $MINIO_VERSION"
          else
            report_issue "MinIO version default mismatch in $file: found default $default_version, expected $MINIO_VERSION"
          fi
        else
          report_issue "MinIO version mismatch in $file: found $used_version, expected $MINIO_VERSION or variable reference"
        fi
      fi
    fi
  done < <(find "$PROJECT_ROOT" -type f -name "*.yml" -o -name "Dockerfile" | grep -v "versions.mk")

# Check Lua version
echo -e "\nChecking Lua version references..."
while IFS= read -r file; do
  if grep -q "lua-" "$file" || grep -q "lua[0-9]" "$file"; then
    # Skip files that don't explicitly need a Lua version
    if [[ "$file" == *"test_haproxy_config.sh"* || 
          "$file" == *"test_haproxy.sh"* || 
          "$file" == *"haproxy_validate.sh"* || 
          "$file" == *"validate_rate_limiting.sh"* ]]; then
      echo -e "${YELLOW}⚠️  Skipping Lua version check for utility script: $file${NC}"
    elif ! grep -q "lua-$LUA_VERSION" "$file" && ! grep -q "lua$LUA_VERSION" "$file" && ! grep -q "\${LUA_VERSION}" "$file"; then
      report_issue "Potential Lua version mismatch in $file"
    else
      report_success "Lua version in $file matches versions.mk: $LUA_VERSION"
    fi
  fi
done < <(find "$PROJECT_ROOT" -name "Dockerfile" -o -name "*.sh" | grep -v "verify_versions.sh" | grep -v ".bin/")

echo -e "\nChecking documentation files..."
# Check README and other documentation for consistent versions
while IFS= read -r file; do
  # Skip files in .bin directory
  if [[ "$file" == *".bin/"* ]]; then
    continue
  fi
  
  if grep -q "Go version" "$file" || grep -q "HAProxy version" "$file" || grep -q "Lua version" "$file"; then
    if ! grep -q "$GO_VERSION" "$file"; then
      report_warning "Documentation in $file may need updating with current Go version: $GO_VERSION"
    fi
    
    if ! grep -q "$HAPROXY_VERSION" "$file"; then
      report_warning "Documentation in $file may need updating with current HAProxy version: $HAPROXY_VERSION"
    fi
    
    if ! grep -q "$LUA_VERSION" "$file"; then
      report_warning "Documentation in $file may need updating with current Lua version: $LUA_VERSION"
    fi
  fi
done < <(find "$PROJECT_ROOT" -name "*.md" -o -name "*.txt" | grep -v "CHANGELOG" | grep -v ".bin/")# Summary
echo -e "\n======================================"
if [[ $ISSUES_FOUND -eq 0 ]]; then
  echo -e "${GREEN}✅ All versions are consistent with versions.mk!${NC}"
  echo "   Go: $GO_VERSION"
  echo "   Lua: $LUA_VERSION"
  echo "   HAProxy: $HAPROXY_VERSION"
  echo "   MinIO: $MINIO_VERSION"
  echo "   Docker Compose: $DOCKER_COMPOSE_VERSION"
  exit 0
else
  echo -e "${RED}❌ Found $ISSUES_FOUND version inconsistencies${NC}"
  echo "   Run 'make update-all-versions' to synchronize all versions"
  exit 1
fi
