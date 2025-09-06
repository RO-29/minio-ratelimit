# Centralized Version Control
# This file defines all versions for tools and dependencies used in the project

# Project directory settings
PROJECT_DIR := $(shell pwd)
# Defining PROJECT_ROOT for backward compatibility with existing scripts
PROJECT_ROOT := $(PROJECT_DIR)

# Go version settings
GO_VERSION := 1.24
# Specific version for toolchain (used in go.mod)
GO_TOOLCHAIN_VERSION := 1.24.5

# Lua version settings
LUA_VERSION := 5.3

# HAProxy version settings
# Using HAProxy 3.0 as required
HAPROXY_VERSION := 3.0

# Docker settings
DOCKER_COMPOSE_VERSION := 2.26.0
DOCKER_MINIMUM_VERSION := 20.10.0

# MinIO version settings
MINIO_VERSION := RELEASE.2025-04-22T22-12-26Z

# Helper function to extract version major/minor/patch
# Usage: $(call get_version_part,VERSION,PART)
# Example: $(call get_version_part,$(GO_VERSION),MAJOR) -> 1
define get_version_part
$(shell echo $(1) | cut -d. -f$(2))
endef

# Function to check if a command exists
define command_exists
$(shell command -v $(1) > /dev/null 2>&1 && echo "true" || echo "false")
endef

# Function to check if a command version meets requirements
# Usage: $(call check_version,COMMAND,CURRENT_VERSION,REQUIRED_VERSION)
define check_version
$(shell if [ $$(printf '%s\n' "$(3)" "$(2)" | sort -V | head -n1) = "$(3)" ]; then echo "true"; else echo "false"; fi)
endef

# Export versions as environment variables for scripts
export GO_VERSION
export LUA_VERSION
export HAPROXY_VERSION
export DOCKER_COMPOSE_VERSION
export MINIO_VERSION
