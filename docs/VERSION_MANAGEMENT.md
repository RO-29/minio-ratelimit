# Version Management System

This document describes the centralized version management system implemented for the MinIO Rate Limiting project.

## Overview

The version management system ensures consistency across all components and environments by:

1. Centralizing version declarations in a single `versions.mk` file
2. Providing tools to check and update versions throughout the project
3. Integrating with CI/CD pipelines to ensure version consistency

## Core Components

### 1. `versions.mk`

The central configuration file that defines all version requirements:

```makefile
# Go version settings
GO_VERSION := 1.24
GO_TOOLCHAIN_VERSION := 1.24.5

# Lua version settings
LUA_VERSION := 5.3

# HAProxy version settings
HAPROXY_VERSION := 3.0

# Docker settings
DOCKER_COMPOSE_VERSION := 2.26.0
DOCKER_MINIMUM_VERSION := 20.10.0

# MinIO version settings
MINIO_VERSION := RELEASE.2025-04-22T22-12-26Z
```

### 2. Version Management Commands

The following Makefile targets are available:

- `make versions`: Display current version requirements and installed versions
- `make check-versions`: Validate if the environment meets version requirements
- `make update-go-version`: Update Go version in all go.mod files
- `make update-haproxy-version`: Update HAProxy version across all files
- `make update-versions`: Update all versions throughout the project

### 3. Version Update Scripts

- `scripts/update_go_version.sh`: Updates Go version in go.mod files
- `scripts/update_haproxy_version.sh`: Updates HAProxy version references
- `scripts/update_all_versions.sh`: Master script to update all versions
- `scripts/check_versions.sh`: Validates environment against requirements

### 4. CI/CD Integration

The CI pipeline template (`.github/workflows/ci.yml.template`) sources version values from `versions.mk` to ensure consistent testing and building environments.

## Usage

### For Developers

1. To view current versions:
   ```bash
   make versions
   ```

2. To check if your environment meets requirements:
   ```bash
   make check-versions
   ```

3. To update versions after changing `versions.mk`:
   ```bash
   make update-versions
   ```

### For CI/CD

1. The CI pipeline automatically uses the versions defined in `versions.mk`
2. Version checks are part of the CI setup process

## Version Update Process

When a dependency needs to be updated:

1. Update the corresponding version in `versions.mk`
2. Run `make update-versions` to propagate changes
3. Test locally with `make check-versions`
4. Commit changes and create a pull request

## Benefits

- Single source of truth for all version requirements
- Consistent development, testing, and production environments
- Simplified dependency management and updates
- Reduced "works on my machine" issues
- Better tracking of version dependencies across components
