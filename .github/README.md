# MinIO Rate Limiting CI/CD

This directory contains CI/CD workflows for validating and testing the MinIO Rate Limiting project.

## Available Workflows

### Main CI Workflow (`ci.yml`)

The main CI workflow runs on every push to main/master branches and pull requests. It includes:

1. **Validation**: Checks HAProxy configurations, Lua scripts, and Go code for syntax errors
2. **Testing**: Runs Go unit tests and generates coverage reports
3. **Integration Testing**: Spins up the system using Docker Compose and runs basic tests
4. **Docker Build**: Tests building the Docker images for both HAProxy and the test tool

### Linting Workflow (`lint.yml`)

A focused workflow for linting that runs when code files change:

1. **Go Linting**: Using golangci-lint to check Go code
2. **HAProxy Validation**: Checking HAProxy configuration syntax
3. **Lua Validation**: Validating Lua scripts

### Setup Workflow (`setup.yml`)

A manual workflow to verify the GitHub Actions environment is properly set up:

- Installs required dependencies
- Generates test configurations
- Verifies tool installations
- Runs validation tests

## Local Development

You can run the same checks locally using Make targets:

```bash
# Run all linting checks
make lint

# Run individual checks
make lint-go
make lint-haproxy
make lint-lua

# Run comprehensive validation
make validate-all

# Run tests with CI settings
make ci-test
make ci-validate
```

## Required Secrets

No secrets are required for the basic validation workflows. For deployment workflows (not included), you would need to add appropriate secrets.

## GitHub Actions Setup

The GitHub Actions workflows use Ubuntu latest runners with the following installed:

- Go 1.21+
- HAProxy
- Lua 5.3
- Docker

## Adding New Tests

To add new tests:

1. Add test files to appropriate directories
2. Update the Makefile targets if needed
3. Run `make validate-all` locally to ensure everything passes
4. Commit and push your changes

## Troubleshooting

If GitHub Actions builds fail:

1. Check the logs for specific error messages
2. Verify that all required files are present in the repository
3. Try running the failing tests locally with `make ci-test` or `make ci-validate`
4. Check for compatibility issues between local and CI environments
