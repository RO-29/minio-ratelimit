# Version Management System

This document describes the centralized version management system for the MinIO Rate Limiting project. The system is designed to ensure consistency in version information across all project components.

## Overview

The MinIO Rate Limiting project uses multiple technologies including:

- Go programming language
- Lua scripting language
- HAProxy
- Docker and Docker Compose
- MinIO server

To maintain consistency and make upgrades easier, all version information is centralized in a single file (`versions.mk`). This approach simplifies updating versions and ensures that all components use compatible versions.

## Centralized Version File

The core of the version management system is the `versions.mk` file at the root of the project. This file contains all version information used throughout the project:

```makefile
# Centralized Version Control
GO_VERSION := 1.24
GO_TOOLCHAIN_VERSION := 1.24.5
LUA_VERSION := 5.3
HAPROXY_VERSION := 3.0
DOCKER_COMPOSE_VERSION := 2.26.0
DOCKER_MINIMUM_VERSION := 20.10.0
MINIO_VERSION := RELEASE.2025-04-22T22-12-26Z
```

## Updating Versions

To update versions, simply edit the `versions.mk` file and run the appropriate update commands:

### Commands for Version Management

| Command                     | Description                                  |
|-----------------------------|----------------------------------------------|
| `make versions`             | Display all current version information      |
| `make check-versions`       | Verify that your environment meets requirements |
| `make verify-versions`      | Check version consistency across the project |
| `make update-go-version`    | Update Go version in all go.mod files        |
| `make update-haproxy-version` | Update HAProxy version in all project files |
| `make update-versions`      | Run all version update scripts               |

### Updating Go Version

When you update the Go version in `versions.mk`:

1. Run `make update-go-version` to update all go.mod files
2. The script will modify:
   - All go.mod files in the project to use the new version
   - Dockerfiles that reference Go versions
   - Documentation that references Go versions

### Updating HAProxy Version

When you update the HAProxy version:

1. Run `make update-haproxy-version`
2. The script will update:
   - Docker Compose files
   - Dockerfiles
   - Documentation

## Version Verification

The version management system includes tools to verify version consistency:

1. **CI Verification**: The consolidated CI workflow (`ci.yml`) automatically checks version consistency in the `build` job after linting and testing complete.

2. **Local Verification**: Run `make verify-versions` to check version consistency across all project files. This command:
   - Checks Go versions in go.mod files
   - Verifies HAProxy version references in Docker files
   - Examines MinIO version references
   - Reviews Lua version references
   - Validates documentation for correct version information

For detailed information about the version verification system, see [VERSION_VERIFICATION.md](./VERSION_VERIFICATION.md).

## Environment Version Checking

To check if your local environment meets the version requirements:

1. Run `make check-versions`
2. The script will check:
   - Installed Go version
   - Installed Lua version
   - Installed HAProxy version
   - Docker version
   - Docker Compose version

## Version Export

For scripts that need access to version information:

1. Source the export script: `source ./scripts/export_versions.sh`
2. This will export all version variables to your environment

## Best Practices

1. **Always update versions.mk first**: When upgrading any component, start by updating the central version file.
2. **Run verification after updates**: After updating versions, run `make verify-versions` to ensure all components are updated.
3. **Use CI checks**: The CI pipeline will verify version consistency on each commit.
4. **Document version changes**: Include version changes in commit messages and update the CHANGELOG.md file.

## Version Related Files

| File                          | Purpose                                   |
|-------------------------------|-------------------------------------------|
| `versions.mk`                 | Central version definitions               |
| `scripts/update_go_version.sh`| Script to update Go version in all files  |
| `scripts/update_haproxy_version.sh` | Update HAProxy version in all files |
| `scripts/check_versions.sh`   | Check installed versions against requirements |
| `scripts/verify_versions.sh`  | Verify version consistency across the project |
| `scripts/export_versions.sh`  | Export versions as environment variables  |
