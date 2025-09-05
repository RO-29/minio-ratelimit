# MinIO Rate Limiting Validation Guide

This document provides a comprehensive guide for validating and testing the MinIO rate limiting solution using HAProxy and Lua scripts.

## Overview

The MinIO rate limiting solution uses HAProxy 3.0 with Lua 5.3 scripts to implement API-based rate limiting for MinIO S3 API requests. The solution includes:

1. HAProxy configuration for routing and rate limiting
2. Lua scripts for dynamic rate limit control
3. Test tools for validation and performance testing

## Prerequisites

- HAProxy 3.0 or later (locally or via Docker)
- Lua 5.3 or later (locally or via Docker)
- Go 1.21 or later (for building test tools)
- Docker and Docker Compose (for running the complete stack)

## Validation Process

### 1. Complete Validation Suite

Run the complete validation suite to verify all components:

```bash
./scripts/verify_all.sh
```

This script will:

- Check for required tools (Go, Docker, HAProxy, Lua)
- Validate HAProxy configurations
- Validate Lua scripts
- Build the rate limit testing tool
- Generate test tokens
- Verify the complete setup

### 2. Individual Validation Steps

#### Validate HAProxy Configuration

```bash
make validate-haproxy
```

This validates that:

- HAProxy configuration syntax is correct
- Required rate limiting directives are present
- HAProxy version is compatible (3.0+)

#### Validate Lua Scripts

```bash
make validate-lua
```

This validates that:

- Lua scripts have correct syntax
- Required rate limiting functions are present
- Lua version is compatible (5.3+)

#### Validate Complete Rate Limiting Setup

```bash
make validate-ratelimit
```

This validates the complete rate limiting setup:

- HAProxy configuration is valid
- Lua scripts are valid
- Rate limiting directives are properly configured
- Test tokens can be generated
- Rate limiting test tool can be built

### 3. Testing the Rate Limiting Functionality

#### Generate Test Tokens

```bash
make ratelimit-tokens
```

This generates test tokens with different rate limits for testing.

#### Build the Rate Limiting Test Tool

```bash
make ratelimit-test-build
```

This builds the Go-based test tool for testing rate limiting.

#### Run Basic Tests

```bash
make test-basic        # Test basic tier accounts
make test-standard     # Test standard tier accounts
make test-premium      # Test premium tier accounts
```

#### Run Advanced Tests

```bash
make test-quick        # Run a quick test (15s)
make test-extended     # Run an extended test (5m)
make test-stress       # Run a stress test to find limits
make test-export       # Export detailed test results to JSON
make test-all-tiers    # Test all tiers with comprehensive analysis
```

## Troubleshooting

### HAProxy Validation Issues

If HAProxy validation fails:

1. Check that HAProxy 3.0+ is installed or Docker is available
2. Verify HAProxy configuration syntax
3. Ensure rate limiting directives (stick-table, lua-load) are present
4. Check for custom HTTP headers for rate limiting

### Lua Script Issues

If Lua validation fails:

1. Check that Lua 5.3+ is installed or Docker is available
2. Verify Lua script syntax
3. Ensure required functions (rate_limit, extract_api_key) are present
4. Check for proper error handling in Lua scripts

### Rate Limiting Not Working

If rate limiting is not working as expected:

1. Verify HAProxy is correctly processing API keys
2. Check that stick tables are correctly configured
3. Verify Lua scripts are correctly loaded
4. Test with different rate limits to ensure thresholds are working

## References

- [HAProxy Documentation](https://www.haproxy.com/documentation/)
- [Lua 5.3 Reference Manual](https://www.lua.org/manual/5.3/)
- [MinIO S3 API Reference](https://min.io/docs/minio/linux/reference/minio-server/minio-server.html)
- [HAProxy Rate Limiting Guide](https://www.haproxy.com/blog/four-examples-of-haproxy-rate-limiting/)
