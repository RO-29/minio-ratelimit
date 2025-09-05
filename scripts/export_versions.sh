#!/bin/bash
# Export environment variables from versions.mk for Docker Compose

# Load versions from versions.mk
if [ -f versions.mk ]; then
  echo "Loading versions from versions.mk"

  # Extract specific variables
  export MINIO_VERSION=$(grep -E '^MINIO_VERSION :=' versions.mk | sed 's/MINIO_VERSION := //')
  export HAPROXY_VERSION=$(grep -E '^HAPROXY_VERSION :=' versions.mk | sed 's/HAPROXY_VERSION := //')
  export LUA_VERSION=$(grep -E '^LUA_VERSION :=' versions.mk | sed 's/LUA_VERSION := //')
  export GO_VERSION=$(grep -E '^GO_VERSION :=' versions.mk | sed 's/GO_VERSION := //')

  echo "Exported environment variables:"
  echo "MINIO_VERSION=$MINIO_VERSION"
  echo "HAPROXY_VERSION=$HAPROXY_VERSION"
  echo "LUA_VERSION=$LUA_VERSION"
  echo "GO_VERSION=$GO_VERSION"
else
  echo "Warning: versions.mk not found. Using default versions."

  # Set default values
  export MINIO_VERSION=RELEASE.2025-04-22T22-12-26Z
  export HAPROXY_VERSION=3.0
  export LUA_VERSION=5.3
  export GO_VERSION=1.24

  echo "Using default versions:"
  echo "MINIO_VERSION=$MINIO_VERSION"
  echo "HAPROXY_VERSION=$HAPROXY_VERSION"
  echo "LUA_VERSION=$LUA_VERSION"
  echo "GO_VERSION=$GO_VERSION"
fi

# Execute the command passed to this script
if [ $# -gt 0 ]; then
  exec "$@"
fi
