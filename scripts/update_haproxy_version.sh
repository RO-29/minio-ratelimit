#!/bin/bash
# Script to update HAProxy version references in project files

# Load the versions from versions.mk
source <(grep -E '^HAPROXY_VERSION' ./versions.mk | sed 's/ := /=/g')

# If version isn't set, use default
HAPROXY_VERSION=${HAPROXY_VERSION:-3.0}

echo "Updating HAProxy version references to $HAPROXY_VERSION"

# Find all files that might contain HAProxy version references
# Excluding .git directory, binary files, and the versions.mk file itself
find . -type f \
  ! -path "./versions.mk" \
  ! -path "./.git/*" \
  ! -path "./node_modules/*" \
  ! -path "./.bin/*" \
  ! -path "*/build/*" \
  -exec grep -l "haproxy:[0-9]\+\.[0-9]\+" {} \; | while read file; do
    
    echo "Updating $file"
    # Replace haproxy:X.Y with haproxy:$HAPROXY_VERSION
    sed -i '' "s/haproxy:[0-9]\+\.[0-9]\+/haproxy:$HAPROXY_VERSION/g" "$file"
done

echo "HAProxy version update complete."
