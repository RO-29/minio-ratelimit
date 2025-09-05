# MinIO Rate Limiting System

## Overview

This project implements a robust rate limiting system for MinIO S3 API using HAProxy 3.0 and Lua scripts. The system provides dynamic, hot-reloadable rate limiting based on API key authentication with zero external dependencies.

## System Architecture

```
┌─────────────┐         ┌────────────────┐         ┌───────────────┐
│ S3 Clients  │ ───────▶│ HAProxy 3.0    │ ───────▶│ MinIO Cluster │
│ (AWS SDK)   │         │ Rate Limiting   │         │ (S3 Storage)  │
└─────────────┘         └────────────────┘         └───────────────┘
                              ▲
                              │
                       ┌──────┴───────┐
                       │ Config Maps  │
                       └──────────────┘
```

## Key Components

### 1. HAProxy 3.0 Layer

- **Function**: Authenticates and rate limits S3 API requests
- **Configuration**: `haproxy/haproxy.cfg` with dynamic map files
- **Benefits**: No restart required for config changes

### 2. Lua Authentication & Rate Limiting

- **Authentication Script**: Extracts API keys from various S3 auth methods
- **Rate Limiting Script**: Applies tiered rate limits based on API key group
- **File Location**: `haproxy/lua/*.lua`

### 3. Configuration Maps

- **API Key Groups**: `haproxy/config/api_key_groups.map`
- **Rate Limits**: `haproxy/config/rate_limits_*.map`
- **Hot-Reloadable**: Changes take effect immediately

### 4. MinIO Backend

- **Function**: S3-compatible object storage
- **Configuration**: Docker container with volume mounts
- **Authentication**: Service accounts with IAM policies

### 5. Version Management

- **Centralized Versions**: All versions defined in `versions.mk`
- **Verification System**: `scripts/verify_versions.sh` ensures consistency
- **Environment Variables**: `scripts/export_versions.sh` for version exports

## Workflow

1. **Request Arrival**: Client sends S3 API request to HAProxy
2. **Authentication**: Lua script extracts API key from request
3. **Group Assignment**: API key mapped to rate limit group
4. **Rate Limiting**: Request counted against tier-specific limits
5. **Forwarding/Rejection**: Request forwarded to MinIO or rejected based on limits
6. **Response**: MinIO response returned to client or error if rate limited

## Rate Limiting Tiers

- **Premium**: Highest limits for priority workloads
- **Standard**: Normal limits for regular applications
- **Basic**: Lower limits for less critical workloads
- **Default**: Fallback limits for unrecognized keys

## Operation & Maintenance

### Modifying Rate Limits

1. Edit the appropriate map file in `haproxy/config/`
2. Changes take effect immediately without restart

### Adding New API Keys

1. Add the API key to `haproxy/config/api_key_groups.map`
2. Format: `<api_key> <group_name>`

### Version Updates

1. Update central version in `versions.mk`
2. Run `make verify-versions` to check consistency
3. Use `source ./scripts/export_versions.sh` for environment variables

### Testing

- Use `make test` to run validation tests
- Use `cmd/ratelimit-test` tool for performance testing

## Development

1. Clone repository
2. Run `make setup` to prepare environment
3. Run `docker-compose up` to start services
4. Access HAProxy stats on port 8404
5. Access MinIO console on port 9001

## CI/CD

GitHub Actions workflows for:
- Linting & validation
- Integration testing
- Version verification
- Performance benchmarking

## Dependencies

- HAProxy 3.0
- Lua 5.3
- Go 1.24
- Docker & Docker Compose 2.26.0+

## Security Features

- SSL/TLS termination
- Support for all S3 authentication methods
- Protection against API key abuse
- Secure key extraction from various auth methods

---

For detailed documentation, see:
- [TECHNICAL_DOCUMENTATION.md](docs/TECHNICAL_DOCUMENTATION.md)
- [VERSION_MANAGEMENT.md](docs/VERSION_MANAGEMENT.md)
- [VALIDATION_GUIDE.md](docs/VALIDATION_GUIDE.md)

# MinIO Rate Limiting CI/CD

This directory contains the consolidated CI/CD workflow for validating and testing the MinIO Rate Limiting project.

## Consolidated CI Workflow (`ci.yml`)

The single CI workflow runs on every push to main/master branches and pull requests. It includes 5 orchestrated jobs:

### 1. **Setup** (`setup`)
- Extracts versions from `versions.mk` 
- Runs environment check using `make check-versions`
- Provides version outputs for other jobs

### 2. **Lint** (`lint`) 
*Depends on: setup*
- Sets up CI environment using `make ci-setup`
- Runs all linting and validation using `make ci-validate`
- Includes: Go linting, HAProxy config validation, Lua script validation

### 3. **Test** (`test`)
*Depends on: setup*
- Runs Go unit tests using `make ci-test`
- Generates and uploads test coverage reports

### 4. **Integration Test** (`integration-test`)
*Depends on: lint, setup*
- Sets up CI environment using `make ci-setup`
- Runs full validation using `make validate-all`
- Starts services using `make up`
- Runs integration tests using `make test-quick`
- Stops services using `make down`
- Uploads integration test results

### 5. **Build** (`build`)
*Depends on: lint, test, setup*
- Builds test tool and verifies functionality
- Runs version verification using `make verify-versions`

## Key Features

- **Single consolidated workflow**: Eliminates duplication from previous multiple workflows
- **Make-based execution**: Uses proven Makefile targets for all operations
- **Proper job dependencies**: Ensures logical execution order and parallel efficiency
- **Version management**: Centralized version extraction from `versions.mk`
- **Docker Compose integration**: Automatic detection of v1 vs v2 via make system

## Local Development

You can run the same checks locally using Make targets:

```bash
# Environment setup and checks
make check-versions      # Check if environment meets requirements
make ci-setup           # Set up CI environment locally
make versions           # Display current project versions

# Linting and validation
make lint               # Run all linting checks
make lint-go            # Lint Go code only
make lint-haproxy       # Validate HAProxy configuration only
make lint-lua           # Validate Lua scripts only
make validate-all       # Run comprehensive validation

# Testing
make ci-test            # Run tests with CI settings
make ci-validate        # Run validations with CI settings
make test-quick         # Run quick integration tests

# Docker services
make up                 # Start all services
make status             # Check service status
make down               # Stop all services
```

## Version Management

All versions are centrally managed in `versions.mk`:

```bash
# Version management commands
make update-versions     # Update all versions
make verify-versions     # Verify version consistency
make update-go-version   # Update Go version in go.mod files
```

## Required Environment

The GitHub Actions workflow uses Ubuntu latest runners with versions specified in `versions.mk`:

- **Go**: 1.24+ (from `GO_VERSION`)
- **HAProxy**: 3.0+ (from `HAPROXY_VERSION`) 
- **Lua**: 5.3+ (from `LUA_VERSION`)
- **Docker**: 20.10.0+ (from `DOCKER_MINIMUM_VERSION`)
- **Docker Compose**: 2.26.0+ (from `DOCKER_COMPOSE_VERSION`)

## CI Environment Variables

The workflow automatically sets:
- `CI=true` - Enables CI mode in make targets
- `CI_NO_COLOR=true` - Disables colors for clean logs
- `HAPROXY_VERSION` - From versions.mk for Docker Compose
- `MINIO_VERSION` - From versions.mk for Docker Compose

## Adding New Tests

To add new tests:

1. Add test files to the appropriate directories
2. Update Makefile targets if needed (in `*_targets.mk` files)
3. Run `make validate-all` locally to ensure everything passes
4. Commit and push - CI will run automatically

## Troubleshooting

If GitHub Actions builds fail:

1. Check the specific job logs for error messages
2. Verify versions in `versions.mk` are correct
3. Try running the failing make target locally:
   - `make ci-setup` for setup issues
   - `make ci-validate` for validation failures
   - `make ci-test` for test failures
   - `make test-quick` for integration test issues
4. Check Docker Compose compatibility with `make up`
5. Verify all required scripts exist and are executable
