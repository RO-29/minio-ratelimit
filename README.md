# MinIO Rate Limiting with HAProxy 3.0

A comprehensive rate limiting solution for MinIO S3 API requests using HAProxy 3.0 in an active-active configuration. This solution provides API key-based rate limiting with group-based limits and hot reload capabilities.

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐
│   HAProxy 1     │    │   HAProxy 2     │
│   Port 80/443   │    │   Port 81/444   │
│                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Rate Limiter│ │    │ │ Rate Limiter│ │
│ │ Lua Script  │ │    │ │ Lua Script  │ │
│ └─────────────┘ │    │ └─────────────┘ │
└─────────┬───────┘    └─────────┬───────┘
          │                      │
          └──────────┬───────────┘
                     │
        ┌────────────▼─────────────┐
        │      MinIO Cluster       │
        │                          │
        │ ┌──────┐    ┌──────────┐ │
        │ │MinIO1│    │  MinIO2  │ │
        │ └──────┘    └──────────┘ │
        └──────────────────────────┘
```

## Features

- **API Key Extraction**: Supports AWS Signature V4 and V2 authentication methods
- **Group-Based Rate Limiting**: Three tiers (Premium: 1000/min, Standard: 500/min, Basic: 100/min)
- **Hot Reload**: Configuration changes without HAProxy restart
- **Active-Active Setup**: Two HAProxy instances for high availability
- **Method-Specific Limits**: Focus on PUT and GET requests
- **No External Dependencies**: Uses HAProxy's built-in stick tables
- **Comprehensive Monitoring**: Built-in stats and logging

## Quick Start

### 1. Generate SSL Certificates (for testing)

```bash
cd ssl
./generate_self_signed.sh
```

### 2. Start the Services

```bash
docker-compose up -d
```

### 3. Configure API Keys

```bash
# Add a new API key to premium group
./scripts/manage_rate_limits.sh add-key AKIAIOSFODNN7EXAMPLE premium

# List all configured keys
./scripts/manage_rate_limits.sh list-keys

# View current configuration
./scripts/manage_rate_limits.sh validate
```

### 4. Test Rate Limiting

```bash
cd test
python3 test_rate_limiting.py --duration 60 --rps 15
```

## Configuration Files

### Core Configuration Files

- `/Users/rohit/minio-ratelimit/haproxy.cfg` - Main HAProxy configuration
- `/Users/rohit/minio-ratelimit/api_key_extractor.lua` - Lua script for API key extraction
- `/Users/rohit/minio-ratelimit/api_key_groups.conf` - API key to group mappings
- `/Users/rohit/minio-ratelimit/docker-compose.yml` - Docker orchestration

### Management Scripts

- `/Users/rohit/minio-ratelimit/scripts/manage_rate_limits.sh` - API key management
- `/Users/rohit/minio-ratelimit/scripts/watch_config.sh` - Configuration hot reload
- `/Users/rohit/minio-ratelimit/test/test_rate_limiting.py` - Rate limiting tests

## API Key Management

### Adding API Keys

```bash
# Add premium tier key (1000 req/min)
./scripts/manage_rate_limits.sh add-key YOUR_ACCESS_KEY premium

# Add standard tier key (500 req/min)  
./scripts/manage_rate_limits.sh add-key YOUR_ACCESS_KEY standard

# Add basic tier key (100 req/min)
./scripts/manage_rate_limits.sh add-key YOUR_ACCESS_KEY basic
```

### Managing API Keys

```bash
# List all keys
./scripts/manage_rate_limits.sh list-keys

# List keys in specific group
./scripts/manage_rate_limits.sh list-keys premium

# Change key group
./scripts/manage_rate_limits.sh change-group YOUR_ACCESS_KEY standard

# Remove key
./scripts/manage_rate_limits.sh remove-key YOUR_ACCESS_KEY

# Create backup
./scripts/manage_rate_limits.sh backup

# Validate configuration
./scripts/manage_rate_limits.sh validate
```

## Rate Limiting Groups

| Group | Limit (req/min) | Use Case |
|-------|----------------|----------|
| Premium | 1000 | High-volume production workloads |
| Standard | 500 | Regular production usage |
| Basic | 100 | Development and testing |

## Hot Reload Process

The solution supports configuration changes without service interruption:

1. **Modify Configuration**: Update `/Users/rohit/minio-ratelimit/api_key_groups.conf`
2. **Automatic Detection**: File watcher detects changes
3. **Reload HAProxy**: Both instances reload configuration
4. **Zero Downtime**: Active connections continue uninterrupted

## Monitoring and Statistics

### HAProxy Stats Interface

- **HAProxy 1**: http://localhost:8404/stats
- **HAProxy 2**: http://localhost:8405/stats

### Command Line Stats

```bash
./scripts/manage_rate_limits.sh stats
```

### Log Analysis

```bash
# View HAProxy logs
docker logs haproxy1
docker logs haproxy2

# Follow live logs
docker logs -f haproxy1
```

## Testing

### Basic Rate Limit Test

```bash
cd test
python3 test_rate_limiting.py --tier basic --duration 30
```

### Comprehensive Testing

```bash
# Test all tiers with concurrent clients
python3 test_rate_limiting.py --duration 60 --concurrent --rps 20

# Test specific endpoint
python3 test_rate_limiting.py --endpoint http://localhost:81 --tier premium
```

## Active-Active HAProxy Setup

The solution runs two HAProxy instances:

- **HAProxy 1**: Ports 80/443 (Primary)
- **HAProxy 2**: Ports 81/444 (Secondary)

Both instances share the same configuration and can handle traffic independently. Use a load balancer or DNS round-robin to distribute traffic between them.

## API Key Extraction Details

The Lua script extracts API keys from multiple S3 authentication methods:

### AWS Signature V4 (Recommended)
```
Authorization: AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20230101/us-east-1/s3/aws4_request, ...
```

### AWS Signature V2 (Legacy)
```
Authorization: AWS AKIAIOSFODNN7EXAMPLE:signature
```

### Query String Authentication
```
GET /?X-Amz-Credential=AKIAIOSFODNN7EXAMPLE%2F20230101%2Fus-east-1%2Fs3%2Faws4_request&...
GET /?AWSAccessKeyId=AKIAIOSFODNN7EXAMPLE&...
```

## Troubleshooting

### Common Issues

1. **Rate Limits Not Applied**
   - Check API key configuration: `./scripts/manage_rate_limits.sh validate`
   - Verify Lua script loading in HAProxy logs
   - Ensure API key matches request format

2. **Configuration Not Reloading**
   - Check file watcher logs: `docker logs config-updater`
   - Verify file permissions on configuration file
   - Manual reload: `docker exec haproxy1 kill -USR2 1`

3. **SSL Certificate Issues**
   - Regenerate certificates: `cd ssl && ./generate_self_signed.sh`
   - Check certificate paths in HAProxy configuration

### Debug Mode

Enable debug logging by modifying `haproxy.cfg`:

```
global
    log stdout local0 debug  # Change from 'info' to 'debug'
```

## Production Considerations

### Security
- Replace self-signed certificates with proper SSL certificates
- Implement proper API key management and rotation
- Use secure file permissions for configuration files
- Enable HAProxy security headers

### Performance
- Tune stick table sizes based on API key count
- Adjust rate limits based on backend capacity
- Monitor memory usage with large API key sets
- Consider HAProxy clustering for very high loads

### High Availability
- Deploy HAProxy instances on separate servers
- Use shared storage for configuration synchronization
- Implement health checks for automatic failover
- Monitor both instances with external monitoring tools

## API Endpoints

### MinIO Access
- **HTTP**: http://localhost (HAProxy 1) or http://localhost:81 (HAProxy 2)
- **HTTPS**: https://localhost (HAProxy 1) or https://localhost:444 (HAProxy 2)

### Direct MinIO Access (for testing)
- **MinIO 1**: http://localhost:9001
- **MinIO 2**: http://localhost:9002

### Monitoring
- **HAProxy 1 Stats**: http://localhost:8404/stats
- **HAProxy 2 Stats**: http://localhost:8405/stats