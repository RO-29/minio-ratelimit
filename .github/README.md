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

1. Add test files to appropriate directories
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

## Migration from Previous Workflows

This consolidates the previous separate workflows:
- ❌ `lint.yml` → Now part of `lint` job in `ci.yml`
- ❌ `integration-tests.yml` → Now part of `integration-test` job in `ci.yml`
- ❌ `setup.yml` → Functionality distributed across jobs in `ci.yml`

All functionality is preserved while eliminating duplication and improving maintainability.