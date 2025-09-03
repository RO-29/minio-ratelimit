# MinIO Rate Limiting Implementation Plan

## Executive Summary

This document outlines a comprehensive rate limiting solution for MinIO S3 API requests using HAProxy 3.0 in an active-active configuration, with an alternative Envoy Proxy solution for advanced scenarios.

## Architecture Analysis

### Current Setup Analysis

Based on your requirements, the solution addresses:

1. **API Key Extraction**: S3 requests contain API keys in multiple formats
2. **Rate Limiting**: Group-based limits without external dependencies  
3. **Active-Active Setup**: Two proxy instances for high availability
4. **Hot Reload**: Configuration changes without service restart

### S3 API Key Locations

API keys are present in S3 requests in these locations:

```
1. Authorization Header (AWS Signature V4):
   Authorization: AWS4-HMAC-SHA256 Credential=ACCESS_KEY/20230101/us-east-1/s3/aws4_request, ...

2. Authorization Header (AWS Signature V2):
   Authorization: AWS ACCESS_KEY:signature

3. Query Parameters (V4):
   GET /?X-Amz-Credential=ACCESS_KEY%2F20230101%2Fus-east-1%2Fs3%2Faws4_request&...

4. Query Parameters (V2):
   GET /?AWSAccessKeyId=ACCESS_KEY&...
```

## Solution Architecture

### Primary Solution: HAProxy 3.0

**Advantages:**
- No external dependencies
- Built-in stick tables for rate tracking
- Lua scripting for complex logic
- Active-active clustering support
- Hot reload via runtime API

**Components:**
1. **HAProxy Frontend**: API key extraction and rate limiting
2. **Lua Script**: Advanced API key parsing and group lookup
3. **Stick Tables**: In-memory rate counters
4. **Configuration Watcher**: Hot reload mechanism

### Alternative Solution: Envoy Proxy

**When to Consider:**
- More complex rate limiting scenarios
- Advanced observability requirements
- Better integration with cloud-native stack
- Support for external rate limiting services

## Implementation Details

### Phase 1: Core Infrastructure Setup

#### 1.1 HAProxy Configuration

**File:** `/Users/rohit/minio-ratelimit/haproxy.cfg`

Key features:
- Dual stick tables (1-minute and 1-second windows)
- API key extraction via Lua
- Group-based rate limits
- S3-compatible error responses
- Comprehensive rate limit headers

#### 1.2 API Key Extraction Logic

**File:** `/Users/rohit/minio-ratelimit/api_key_extractor.lua`

Capabilities:
- AWS Signature V4/V2 support
- Query parameter extraction
- Dynamic group configuration loading
- Rate limit calculation helpers

#### 1.3 Group Configuration

**File:** `/Users/rohit/minio-ratelimit/api_key_groups.conf`

Format:
```
API_KEY:GROUP_NAME

# Examples:
AKIAIOSFODNN7EXAMPLE:premium
standard-user-001:standard
basic-user-001:basic
```

### Phase 2: Rate Limiting Logic

#### 2.1 Rate Limit Tiers

| Tier | Per Minute | Per Second (Burst) | Use Case |
|------|------------|-------------------|----------|
| Premium | 1000 | 50 | High-volume production |
| Standard | 500 | 25 | Regular production |
| Basic | 100 | 10 | Development/testing |
| Anonymous | 50 | 5 | Unauthenticated requests |

#### 2.2 Method-Specific Limits

Focus on PUT and GET requests as requested:
- Rate limits apply primarily to PUT/GET operations
- Other methods (HEAD, OPTIONS) have relaxed limits
- POST/DELETE can be added to rate limiting as needed

### Phase 3: Hot Reload Implementation

#### 3.1 Configuration Watching

**File:** `/Users/rohit/minio-ratelimit/scripts/watch_config.sh`

Mechanism:
- `inotify` monitors configuration file changes
- Automatic HAProxy reload via runtime API
- Zero-downtime configuration updates

#### 3.2 Management Interface

**File:** `/Users/rohit/minio-ratelimit/scripts/manage_rate_limits.sh`

Operations:
```bash
# Add/update API key
./manage_rate_limits.sh add-key ACCESS_KEY premium

# Remove API key  
./manage_rate_limits.sh remove-key ACCESS_KEY

# List keys by group
./manage_rate_limits.sh list-keys premium

# Backup/restore configuration
./manage_rate_limits.sh backup
./manage_rate_limits.sh restore backup_file.conf
```

### Phase 4: Active-Active Setup

#### 4.1 HAProxy Instances

- **Instance 1**: Ports 80/443, Stats on 8404
- **Instance 2**: Ports 81/444, Stats on 8405
- Shared configuration files
- Independent stick tables (limitation addressed below)

#### 4.2 Stick Table Synchronization Limitation

**Challenge:** HAProxy stick tables don't synchronize between instances.

**Solutions:**

1. **Acceptable for Most Cases:**
   - Each instance maintains separate counters
   - Effective rate limiting still achieved
   - Slight over-allowance possible but manageable

2. **Advanced Synchronization (Optional):**
   - Use HAProxy peers for stick table sync
   - Requires network communication between instances
   - More complex setup but perfect synchronization

## Alternative: Envoy Proxy Solution

### When to Use Envoy Instead

**Scenarios:**
- Need for advanced rate limiting (e.g., per-user quotas)
- Better observability and metrics
- Integration with service mesh
- External rate limiting service requirement

**File:** `/Users/rohit/minio-ratelimit/envoy/envoy.yaml`

**Advantages:**
- More advanced rate limiting filters
- Better metrics and observability
- Support for external rate limiting services
- Cloud-native architecture alignment

## Deployment Instructions

### Quick Start with HAProxy

```bash
# 1. Generate SSL certificates (for testing)
cd ssl && ./generate_self_signed.sh

# 2. Start services
docker-compose up -d

# 3. Configure API keys
./scripts/manage_rate_limits.sh add-key YOUR_ACCESS_KEY premium

# 4. Test rate limiting
cd test && python3 test_rate_limiting.py --duration 60
```

### Alternative Envoy Deployment

```bash
# Use Envoy instead of HAProxy
docker-compose -f docker-compose-envoy.yml up -d
```

## Testing and Validation

### Automated Testing

**File:** `/Users/rohit/minio-ratelimit/test/test_rate_limiting.py`

Test scenarios:
- API key extraction validation
- Rate limit enforcement
- Group-based limits
- Concurrent client behavior
- Response header verification

### Manual Testing

```bash
# Test with AWS CLI
aws s3 ls --endpoint-url http://localhost

# Test with curl
curl -H "Authorization: AWS4-HMAC-SHA256 Credential=test-premium-key/..." \
     http://localhost/bucket/
```

## Monitoring and Observability

### HAProxy Statistics

- **Interface**: http://localhost:8404/stats
- **Metrics**: Request rates, error counts, backend health
- **Real-time monitoring**: Active connections, queue depths

### Custom Metrics

Rate limiting specific metrics:
- Requests per API key per minute
- Rate limit violations
- Group distribution
- Response time impact

### Log Analysis

```bash
# View rate limiting logs
docker logs haproxy1 | grep "Rate limit"

# Monitor configuration changes
docker logs config-updater
```

## Production Considerations

### Security Hardening

1. **SSL/TLS Configuration**
   - Replace self-signed certificates
   - Configure proper cipher suites
   - Enable HSTS headers

2. **Access Control**
   - Restrict stats interface access
   - Secure configuration file permissions
   - Enable HAProxy security headers

### Performance Optimization

1. **Stick Table Sizing**
   ```
   # Adjust based on API key count
   stick-table type string len 64 size 100k expire 2m
   ```

2. **Resource Allocation**
   - Monitor memory usage
   - Adjust HAProxy worker processes
   - Optimize Lua script performance

### High Availability

1. **Load Balancer Setup**
   - Use external load balancer for HAProxy instances
   - Implement health checks
   - Configure failover mechanisms

2. **Backup and Recovery**
   - Automated configuration backups
   - Disaster recovery procedures
   - Configuration version control

## Limitations and Workarounds

### HAProxy Limitations

1. **Stick Table Synchronization**
   - **Issue**: No built-in sync between instances
   - **Workaround**: Use HAProxy peers or accept slight over-allowance

2. **Complex API Key Lookup**
   - **Issue**: Limited external data source integration
   - **Workaround**: File-based configuration with hot reload

3. **Advanced Rate Limiting**
   - **Issue**: Limited to simple token bucket algorithms
   - **Workaround**: Use Envoy for complex scenarios

### Envoy Advantages

1. **Better Rate Limiting**: More sophisticated algorithms
2. **External Integration**: Support for external rate limit services
3. **Observability**: Rich metrics and tracing
4. **Extensibility**: Plugin architecture for custom logic

## Migration Strategy

### Phase 1: HAProxy Implementation (Recommended Start)
- Quick setup and deployment
- Covers 90% of rate limiting needs
- Easy to understand and maintain

### Phase 2: Optional Envoy Migration
- Only if advanced features needed
- Gradual migration possible
- Better long-term scalability

## Support and Maintenance

### Configuration Management

```bash
# Daily operations
./scripts/manage_rate_limits.sh validate
./scripts/manage_rate_limits.sh backup
./scripts/manage_rate_limits.sh stats

# Weekly maintenance
docker-compose restart config-updater
./scripts/manage_rate_limits.sh list-keys > weekly_report.txt
```

### Troubleshooting Guide

1. **Rate Limits Not Applied**
   - Check API key extraction in logs
   - Verify configuration file format
   - Test Lua script functionality

2. **High Resource Usage**
   - Monitor stick table memory usage
   - Check for configuration loops
   - Optimize Lua script performance

3. **Configuration Not Reloading**
   - Check file watcher service status
   - Verify file permissions
   - Manual reload via stats socket

This implementation plan provides a production-ready rate limiting solution that meets all your requirements while offering flexibility for future enhancements.