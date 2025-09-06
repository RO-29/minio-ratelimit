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

# Project directory settings
PROJECT_DIR := $(shell pwd)
# Defining PROJECT_ROOT for backward compatibility with existing scripts
PROJECT_ROOT := $(PROJECT_DIR)
```

## Path Management

The `versions.mk` file also defines important path variables used throughout the project:

```makefile
# Project directory settings
PROJECT_DIR := $(shell pwd)
# Defining PROJECT_ROOT for backward compatibility with existing scripts
PROJECT_ROOT := $(PROJECT_DIR)
```

These variables ensure consistent path resolution regardless of the directory from which commands are executed:

- `PROJECT_DIR`: Represents the current directory using `$(shell pwd)`
- `PROJECT_ROOT`: An alias for `PROJECT_DIR` maintained for backward compatibility with existing scripts

All scripts and Makefile targets use these variables to reference files and directories, ensuring paths are resolved correctly relative to the project root.

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

## CI/CD Integration

### Automated Version Management in CI Pipeline

The consolidated CI workflow integrates deeply with the version management system to ensure consistency across all build environments:

#### **Version Extraction in CI**

The CI pipeline's `setup` job extracts version information directly from `versions.mk` and makes it available to all downstream jobs:

```yaml
- name: Extract version information
  id: extract_versions
  run: |
    source ./scripts/export_versions.sh 2>/dev/null || true
    
    GO_VERSION=$(grep -E '^GO_VERSION :=' versions.mk | sed 's/GO_VERSION := //')
    HAPROXY_VERSION=$(grep -E '^HAPROXY_VERSION :=' versions.mk | sed 's/HAPROXY_VERSION := //')
    MINIO_VERSION=$(grep -E '^MINIO_VERSION :=' versions.mk | sed 's/MINIO_VERSION := //')
    
    echo "go_version=$GO_VERSION" >> $GITHUB_OUTPUT
    echo "haproxy_version=$HAPROXY_VERSION" >> $GITHUB_OUTPUT  
    echo "minio_version=$MINIO_VERSION" >> $GITHUB_OUTPUT
```

#### **Version Usage Across CI Jobs**

All CI jobs reference the extracted version information to ensure consistency:

```yaml
jobs:
  lint:
    needs: setup
    steps:
      - uses: actions/setup-go@v4
        with:
          go-version: ${{ needs.setup.outputs.go_version }}

  integration-test:
    needs: [lint, setup]
    env:
      HAPROXY_VERSION: ${{ needs.setup.outputs.haproxy_version }}
      MINIO_VERSION: ${{ needs.setup.outputs.minio_version }}
```

#### **Automated Version Validation**

The CI system includes multiple checkpoints for version validation:

1. **Setup Job**: Runs `make check-versions` to validate the CI environment meets requirements
2. **Build Job**: Executes `make verify-versions` to ensure version consistency across all project files
3. **Integration Tests**: Uses extracted versions to ensure proper component compatibility

#### **CI-Specific Version Handling**

The CI system handles version detection gracefully in automated environments:

- **Docker Compose Detection**: Automatically detects and uses appropriate Docker Compose version (v1 vs v2)
- **Go Module Validation**: Ensures all go.mod files reference the correct Go version from `versions.mk`
- **Environment Compatibility**: Validates that the CI environment can meet all version requirements

#### **Version Mismatch Prevention**

The CI pipeline prevents version mismatches through:

- **Early Detection**: Version validation occurs in the setup phase before any builds
- **Consistent Extraction**: All jobs use the same version extraction method
- **Automated Updates**: Version update scripts are validated to maintain consistency
- **Verification Gates**: Build job includes comprehensive version verification before completion

#### **Local CI Simulation**

Developers can simulate CI version handling locally:

```bash
# Extract versions like CI does
source ./scripts/export_versions.sh

# Validate versions like CI setup job
make check-versions

# Run version verification like CI build job  
make verify-versions

# Check specific version consistency
make update-go-version --dry-run    # Preview changes
make update-haproxy-version --dry-run
```

### Version Management Best Practices for CI

1. **Update versions.mk first**: Always update the central version file before committing changes
2. **Test locally**: Run `make check-versions` and `make verify-versions` locally before pushing
3. **Monitor CI**: Watch for version-related failures in the CI pipeline
4. **Automate updates**: Use the provided scripts rather than manual file edits
5. **Document changes**: Version updates should be clearly documented in commit messages

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
