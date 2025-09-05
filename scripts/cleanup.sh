#!/bin/bash
# Cleanup script to consolidate resources and move unnecessary files to .bin directory
# This helps keep the project structure clean while preserving useful artifacts

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

print_styled "$BLUE" "=== MinIO Rate Limiting Project Cleanup ==="

# Ensure .bin directory structure exists
mkdir -p ./.bin/archived_scripts
mkdir -p ./.bin/test_results
mkdir -p ./.bin/backups
mkdir -p ./.bin/build_artifacts
mkdir -p ./.bin/debug_tools
mkdir -p ./.bin/docs_archive
mkdir -p ./.bin/temp_files
mkdir -p ./.bin/old_configs
mkdir -p ./.bin/old_lua_scripts
mkdir -p ./.bin/old_haproxy_configs
mkdir -p ./.bin/test_data/sample_requests
mkdir -p ./.bin/development_tools

# Move test results
print_styled "$BLUE" "Moving test results to .bin/test_results..."
[ -d "./test-results" ] && cp -r ./test-results/* ./.bin/test_results/ 2>/dev/null
rm -rf ./test-results 2>/dev/null
[ -d "./cmd/ratelimit-test/results" ] && cp -r ./cmd/ratelimit-test/results/* ./.bin/test_results/ 2>/dev/null
[ -d "./cmd/ratelimit-test/docker-results" ] && cp -r ./cmd/ratelimit-test/docker-results/* ./.bin/test_results/ 2>/dev/null

# Move build artifacts
print_styled "$BLUE" "Moving build artifacts to .bin/build_artifacts..."
[ -d "./cmd/ratelimit-test/build" ] && cp -r ./cmd/ratelimit-test/build/* ./.bin/build_artifacts/ 2>/dev/null

# Move backups
print_styled "$BLUE" "Moving backups to .bin/backups..."
[ -d "./backups" ] && cp -r ./backups/* ./.bin/backups/ 2>/dev/null
rm -rf ./backups 2>/dev/null

# Find and move .old, .bak files and debug scripts
print_styled "$BLUE" "Moving old/backup files and debug scripts..."
find . -name "*.old" -o -name "*.bak" -o -name "*_old*" | while read -r file; do
  # Skip files already in .bin
  if [[ "$file" == *".bin"* ]]; then
    continue
  fi
  filename=$(basename "$file")
  cp "$file" ./.bin/archived_scripts/ 2>/dev/null
  rm "$file" 2>/dev/null
  print_styled "$GREEN" "  ✓ Moved $filename"
done

# Move old script versions
[ -f "./scripts/test_haproxy_config.sh.old" ] && mv ./scripts/test_haproxy_config.sh.old ./.bin/archived_scripts/
[ -f "./scripts/manage-dynamic-limits.old" ] && mv ./scripts/manage-dynamic-limits.old ./.bin/archived_scripts/

# Move debug scripts and tools
[ -f "./.bin/debug_extraction.sh" ] && mv ./.bin/debug_extraction.sh ./.bin/debug_tools/
[ -f "./.bin/debug_v4_analysis.go" ] && mv ./.bin/debug_v4_analysis.go ./.bin/debug_tools/
[ -f "./.bin/v4_analysis.go" ] && mv ./.bin/v4_analysis.go ./.bin/debug_tools/
[ -f "./.bin/test_v2_debug.go" ] && mv ./.bin/test_v2_debug.go ./.bin/debug_tools/
[ -f "./.bin/real_signatures_demo.go" ] && mv ./.bin/real_signatures_demo.go ./.bin/debug_tools/
[ -f "./.bin/test_single_premium.go" ] && mv ./.bin/test_single_premium.go ./.bin/debug_tools/
[ -f "./.bin/test-minio-curl.sh" ] && mv ./.bin/test-minio-curl.sh ./.bin/debug_tools/

# Move performance reports to docs archive
[ -f "./.bin/OPTIMIZATION_PERFORMANCE_REPORT.md" ] && mv ./.bin/OPTIMIZATION_PERFORMANCE_REPORT.md ./.bin/docs_archive/
[ -f "./.bin/PERFORMANCE_REPORT.md" ] && mv ./.bin/PERFORMANCE_REPORT.md ./.bin/docs_archive/

# Clean up any empty .DS_Store files
find . -name ".DS_Store" -delete

# Consolidate test data into .bin
print_styled "$BLUE" "Consolidating test data..."

# Move development and test tools that aren't needed in the main directory
print_styled "$BLUE" "Moving development tools..."
if [ -d "./.bin/load-test" ]; then
  mv ./.bin/load-test/* ./.bin/development_tools/ 2>/dev/null
  rmdir ./.bin/load-test 2>/dev/null
fi

if [ -d "./.bin/rate-diagnostic" ]; then
  mv ./.bin/rate-diagnostic/* ./.bin/development_tools/ 2>/dev/null
  rmdir ./.bin/rate-diagnostic 2>/dev/null
fi

if [ -d "./.bin/performance-comparison" ]; then
  mv ./.bin/performance-comparison/* ./.bin/docs_archive/ 2>/dev/null
  rmdir ./.bin/performance-comparison 2>/dev/null
fi

# Move old configs from .bin root to proper subdirectories
print_styled "$BLUE" "Organizing old configuration files..."
if [ -f "./.bin/api_key_extractor.lua" ]; then
  mv ./.bin/api_key_extractor.lua ./.bin/old_lua_scripts/
fi

if [ -f "./.bin/dynamic_rate_limiter_optimized.lua" ]; then
  mv ./.bin/dynamic_rate_limiter_optimized.lua ./.bin/old_lua_scripts/
fi

if [ -f "./.bin/extract_api_keys_optimized.lua" ]; then
  mv ./.bin/extract_api_keys_optimized.lua ./.bin/old_lua_scripts/
fi

if [ -f "./.bin/haproxy_optimized.cfg" ]; then
  mv ./.bin/haproxy_optimized.cfg ./.bin/old_haproxy_configs/
fi

# Move any loose Go files in .bin to debug_tools
for gofile in ./.bin/*.go; do
  if [ -f "$gofile" ]; then
    mv "$gofile" ./.bin/debug_tools/
  fi
done

# Move any loose shell scripts in .bin to development_tools
for shfile in ./.bin/*.sh; do
  if [ -f "$shfile" ]; then
    mv "$shfile" ./.bin/development_tools/
  fi
done

# Move any management tools to development_tools
if [ -f "./.bin/manage-api-keys" ]; then
  mv ./.bin/manage-api-keys ./.bin/development_tools/
fi

if [ -f "./.bin/manage-api-keys-dynamic" ]; then
  mv ./.bin/manage-api-keys-dynamic ./.bin/development_tools/
fi

if [ -f "./.bin/manage.sh" ]; then
  mv ./.bin/manage.sh ./.bin/development_tools/
fi

# Move the .bin/compose directory to development_tools if it exists
if [ -d "./.bin/compose" ]; then
  mkdir -p ./.bin/development_tools/compose
  cp -r ./.bin/compose/* ./.bin/development_tools/compose/ 2>/dev/null
  rm -rf ./.bin/compose 2>/dev/null
fi

# Move the .bin/configs directory to old_configs if it exists
if [ -d "./.bin/configs" ]; then
  cp -r ./.bin/configs/* ./.bin/old_configs/ 2>/dev/null
  rm -rf ./.bin/configs 2>/dev/null
fi

# Move the .bin/other directory contents to appropriate subdirectories
if [ -d "./.bin/other" ]; then
  # Create a temporary directory to examine files
  mkdir -p ./.bin/temp_files/other_examination
  cp -r ./.bin/other/* ./.bin/temp_files/other_examination/ 2>/dev/null

  # Process files based on extension
  find ./.bin/temp_files/other_examination -type f -name "*.lua" -exec mv {} ./.bin/old_lua_scripts/ \;
  find ./.bin/temp_files/other_examination -type f -name "*.cfg" -exec mv {} ./.bin/old_haproxy_configs/ \;
  find ./.bin/temp_files/other_examination -type f -name "*.go" -exec mv {} ./.bin/debug_tools/ \;
  find ./.bin/temp_files/other_examination -type f -name "*.sh" -exec mv {} ./.bin/development_tools/ \;
  find ./.bin/temp_files/other_examination -type f -name "*.json" -exec mv {} ./.bin/test_data/ \;
  find ./.bin/temp_files/other_examination -type f -name "*.md" -exec mv {} ./.bin/docs_archive/ \;

  # Move any remaining files to archived_scripts
  find ./.bin/temp_files/other_examination -type f -exec mv {} ./.bin/archived_scripts/ \;

  # Clean up
  rm -rf ./.bin/temp_files/other_examination
  rm -rf ./.bin/other 2>/dev/null
fi

# Generate a summary of what was moved
print_styled "$BLUE" "Generating cleanup summary..."
echo "Cleanup Summary ($(date))" > ./.bin/CLEANUP_SUMMARY.md
echo "=======================" >> ./.bin/CLEANUP_SUMMARY.md
echo "" >> ./.bin/CLEANUP_SUMMARY.md
echo "## Directories Created" >> ./.bin/CLEANUP_SUMMARY.md
find ./.bin -type d | sort >> ./.bin/CLEANUP_SUMMARY.md
echo "" >> ./.bin/CLEANUP_SUMMARY.md
echo "## Files Moved/Archived" >> ./.bin/CLEANUP_SUMMARY.md
echo "Total files in .bin: $(find ./.bin -type f | wc -l)" >> ./.bin/CLEANUP_SUMMARY.md
echo "" >> ./.bin/CLEANUP_SUMMARY.md
echo "### By Type" >> ./.bin/CLEANUP_SUMMARY.md
echo "- Lua scripts: $(find ./.bin -name "*.lua" | wc -l)" >> ./.bin/CLEANUP_SUMMARY.md
echo "- Go files: $(find ./.bin -name "*.go" | wc -l)" >> ./.bin/CLEANUP_SUMMARY.md
echo "- Shell scripts: $(find ./.bin -name "*.sh" | wc -l)" >> ./.bin/CLEANUP_SUMMARY.md
echo "- HAProxy configs: $(find ./.bin -name "*.cfg" | wc -l)" >> ./.bin/CLEANUP_SUMMARY.md
echo "- Documentation: $(find ./.bin -name "*.md" | wc -l)" >> ./.bin/CLEANUP_SUMMARY.md
echo "- JSON files: $(find ./.bin -name "*.json" | wc -l)" >> ./.bin/CLEANUP_SUMMARY.md

print_styled "$GREEN" "✅ Cleanup complete! Unnecessary files have been moved to .bin directory."
print_styled "$BLUE" "Summary saved to ./.bin/CLEANUP_SUMMARY.md"
print_styled "$YELLOW" "NOTE: This script preserves all files by moving them to .bin - nothing is permanently deleted."
print_styled "$YELLOW" "To review what was moved, check the .bin directory and its subdirectories."
