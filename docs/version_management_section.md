## Version Management

### Centralized Version Control System

The project implements a comprehensive centralized version control system to ensure consistency across all components, testing environments, and CI/CD pipelines. This system is built around a central `versions.mk` file and supporting tools that propagate version requirements across the project.

### Core Components

#### 1. Central Version Declaration (`versions.mk`)

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

#### 2. Management Tools

The version management system provides several tools and commands:

- **Version Information**: `make versions` displays current version requirements and installed versions
- **Environment Validation**: `make check-versions` validates if the environment meets requirements
- **Update Mechanisms**:
  - `make update-go-version`: Updates Go version in go.mod files
  - `make update-haproxy-version`: Updates HAProxy version references
  - `make update-versions`: Updates all versions throughout the project

#### 3. Supporting Scripts

- **Go Version Management**: `scripts/update_go_version.sh` updates Go versions in go.mod files
- **HAProxy Version Management**: `scripts/update_haproxy_version.sh` updates HAProxy version references
- **Version Validation**: `scripts/check_versions.sh` validates the environment against requirements

### CI/CD Integration

The version management system integrates with CI/CD pipelines to ensure consistent environments:

```yaml
env:
  # These values are sourced from versions.mk
  GO_VERSION: 1.24
  LUA_VERSION: 5.3
  HAPROXY_VERSION: 3.0
  DOCKER_COMPOSE_VERSION: 2.26.0
  DOCKER_MINIMUM_VERSION: 20.10.0
```

### Version Update Process

When updating a dependency version:

1. Update the corresponding version in `versions.mk`
2. Run `make update-versions` to propagate changes
3. Test locally with `make check-versions`
4. Verify all functionality with the new versions
5. Commit changes and create a pull request

For additional details on the version management system, see [docs/VERSION_MANAGEMENT.md](./docs/VERSION_MANAGEMENT.md).
