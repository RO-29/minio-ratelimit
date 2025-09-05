## 🔧 **Version Requirements**

This project has the following version requirements:

| Dependency | Required Version | Notes |
|------------|------------------|-------|
| Go | >= ${GO_VERSION} | Used for testing tools and rate limit tests |
| HAProxy | >= ${HAPROXY_VERSION} | Core component for rate limiting |
| Lua | >= ${LUA_VERSION} | Used for authentication and rate limiting logic |
| Docker | >= ${DOCKER_MINIMUM_VERSION} | Required for containerized setup |
| Docker Compose | >= ${DOCKER_COMPOSE_VERSION} | Both v1 and v2 supported (see [Docker Compose Compatibility](#-docker-compose-compatibility)) |

### **Version Management**

All version requirements are centralized in the `versions.mk` file and can be viewed using:

```bash
make versions
```

To verify your environment meets all requirements:

```bash
make check-versions
```

If your local Go version doesn't match the required version, you can update go.mod files with:

```bash
make update-go-version
```

For HAProxy version updates across the project:

```bash
make update-haproxy-version
```

To update all versions at once:

```bash
make update-versions
```
