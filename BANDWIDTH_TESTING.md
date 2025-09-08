# Bandwidth-Based Rate Limiting Testing Guide

## Overview

This document provides comprehensive testing instructions for the newly implemented bandwidth-based rate limiting feature. The system now supports both request-based and bandwidth-based rate limiting working together.

## Quick Setup Test

### 1. Start the System
```bash
# Start all services
make up

# Verify HAProxy is running with bandwidth filters
docker logs haproxy1 | grep -i bandwidth
```

### 2. Configure Bandwidth Limits
```bash
# Set bandwidth limits for different tiers
./scripts/manage-dynamic-limits set-download-limit premium 50M --hot-reload
./scripts/manage-dynamic-limits set-upload-limit premium 25M --hot-reload

./scripts/manage-dynamic-limits set-download-limit standard 10M --hot-reload  
./scripts/manage-dynamic-limits set-upload-limit standard 5M --hot-reload

./scripts/manage-dynamic-limits set-download-limit basic 2M --hot-reload
./scripts/manage-dynamic-limits set-upload-limit basic 1M --hot-reload

# Verify configuration
./scripts/manage-dynamic-limits show-bandwidth-config
```

### 3. Test Bandwidth Limiting

#### Upload Speed Test (Large File Upload)
```bash
# Create a test file (10MB)
dd if=/dev/zero of=/tmp/test-10mb.bin bs=1M count=10

# Test premium tier upload (should get ~25MB/s limit)
API_KEY="PREMIUMKEY123"  # Use actual premium key from your config
time curl -X PUT "http://localhost/test-bucket/large-upload-test" \
  -H "Authorization: AWS4-HMAC-SHA256 Credential=$API_KEY/20241206/us-east-1/s3/aws4_request, SignedHeaders=host, Signature=dummy" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @/tmp/test-10mb.bin \
  -w "Upload Speed: %{speed_upload} bytes/sec\n"

# Test basic tier upload (should get ~1MB/s limit)  
API_KEY="BASICKEY123"  # Use actual basic key from your config
time curl -X PUT "http://localhost/test-bucket/large-upload-basic" \
  -H "Authorization: AWS4-HMAC-SHA256 Credential=$API_KEY/20241206/us-east-1/s3/aws4_request, SignedHeaders=host, Signature=dummy" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @/tmp/test-10mb.bin \
  -w "Upload Speed: %{speed_upload} bytes/sec\n"
```

#### Download Speed Test
```bash  
# First, upload a large file to test downloads
curl -X PUT "http://localhost/test-bucket/download-test-file" \
  -H "Authorization: AWS testkey:signature" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @/tmp/test-10mb.bin

# Test premium tier download (should get ~50MB/s limit)
API_KEY="PREMIUMKEY123"
time curl -o /tmp/downloaded-premium.bin "http://localhost/test-bucket/download-test-file" \
  -H "Authorization: AWS4-HMAC-SHA256 Credential=$API_KEY/20241206/us-east-1/s3/aws4_request, SignedHeaders=host, Signature=dummy" \
  -w "Download Speed: %{speed_download} bytes/sec\n"

# Test basic tier download (should get ~2MB/s limit)
API_KEY="BASICKEY123"  
time curl -o /tmp/downloaded-basic.bin "http://localhost/test-bucket/download-test-file" \
  -H "Authorization: AWS4-HMAC-SHA256 Credential=$API_KEY/20241206/us-east-1/s3/aws4_request, SignedHeaders=host, Signature=dummy" \
  -w "Download Speed: %{speed_download} bytes/sec\n"
```

### 4. Verify Response Headers
```bash
# Check bandwidth limit headers in responses
curl -I "http://localhost/test-bucket/" \
  -H "Authorization: AWS4-HMAC-SHA256 Credential=PREMIUMKEY123/20241206/us-east-1/s3/aws4_request, SignedHeaders=host, Signature=dummy" \
  | grep -i bandwidth

# Expected headers:
# X-Bandwidth-Limit-Download: 52428800
# X-Bandwidth-Limit-Upload: 26214400  
# X-Bandwidth-Current-Download: <current_usage>
# X-Bandwidth-Current-Upload: <current_usage>
```

## Management Script Testing

### Test Bandwidth Configuration Commands
```bash
# Test unit conversion
./scripts/manage-dynamic-limits set-download-limit test-group 100M --hot-reload
./scripts/manage-dynamic-limits get-bandwidth-limits test-group

# Test with different units
./scripts/manage-dynamic-limits set-upload-limit test-group 512K --hot-reload
./scripts/manage-dynamic-limits set-download-limit test-group 2048000  # Raw bytes
./scripts/manage-dynamic-limits get-bandwidth-limits test-group

# Test configuration display
./scripts/manage-dynamic-limits show-bandwidth-config
./scripts/manage-dynamic-limits show-stats
```

### Test Backup and Restore
```bash
# Create backup before testing
./scripts/manage-dynamic-limits backup

# Change some bandwidth limits
./scripts/manage-dynamic-limits set-download-limit premium 100M --hot-reload

# List available backups and restore
./scripts/manage-dynamic-limits restore 20241206_123456  # Use actual backup timestamp
```

## Comprehensive Testing Scenarios

### Scenario 1: Dual Rate Limiting (Request + Bandwidth)
Test that both request-based and bandwidth-based limits work simultaneously:

```bash
# Configure a group with tight request limits but generous bandwidth
./scripts/manage-dynamic-limits set-minute-limit test-dual 10 --hot-reload
./scripts/manage-dynamic-limits set-download-limit test-dual 50M --hot-reload

# Add test API key to this group
./scripts/manage-dynamic-limits add-key TESTDUALKEY123 test-dual --hot-reload

# Test: Should hit request limit before bandwidth limit
for i in {1..15}; do
  curl -s -o /dev/null -w "%{http_code} " "http://localhost/test-bucket/file$i" \
    -H "Authorization: AWS TESTDUALKEY123:signature"
done
echo ""
# Expected: First ~10 should succeed (200), rest should fail (429)
```

### Scenario 2: Bandwidth-Only Limiting
Test with high request limits but low bandwidth limits:

```bash  
# Configure generous request limits but tight bandwidth
./scripts/manage-dynamic-limits set-minute-limit test-bw 1000 --hot-reload
./scripts/manage-dynamic-limits set-download-limit test-bw 100K --hot-reload  # Very low

./scripts/manage-dynamic-limits add-key TESTBWKEY123 test-bw --hot-reload

# Upload large file - should be throttled by bandwidth, not requests
time curl -X PUT "http://localhost/test-bucket/bw-test" \
  -H "Authorization: AWS TESTBWKEY123:signature" \
  --data-binary @/tmp/test-10mb.bin \
  -w "Speed: %{speed_upload} bytes/sec should be ~100KB/s\n"
```

### Scenario 3: Different Tiers Performance
Compare bandwidth performance across all tiers:

```bash
# Test script to compare all tiers
cat > /tmp/test_all_tiers.sh << 'EOF'
#!/bin/bash
for tier in premium standard basic default; do
  echo "Testing $tier tier bandwidth..."
  
  # Find an API key for this tier  
  API_KEY=$(grep " $tier\$" haproxy/config/api_key_groups.map | head -1 | awk '{print $1}')
  if [ -z "$API_KEY" ]; then
    echo "  No API key found for $tier tier"
    continue
  fi
  
  echo "  Using API key: $API_KEY"
  
  # Test upload speed
  start_time=$(date +%s.%N)
  curl -s -X PUT "http://localhost/test-bucket/tier-test-$tier" \
    -H "Authorization: AWS $API_KEY:signature" \
    --data-binary @/tmp/test-10mb.bin
  end_time=$(date +%s.%N)
  
  duration=$(echo "$end_time - $start_time" | bc)
  speed=$(echo "scale=2; 10485760 / $duration" | bc)
  speed_mb=$(echo "scale=2; $speed / 1048576" | bc)
  
  echo "  Upload time: ${duration}s, Speed: ${speed_mb} MB/s"
  echo ""
done
EOF

chmod +x /tmp/test_all_tiers.sh
/tmp/test_all_tiers.sh
```

## Monitoring and Troubleshooting

### Check HAProxy Stats
```bash
# View bandwidth statistics
curl -s "http://localhost:8404/stats" | grep -A5 -B5 bandwidth

# Check stick table contents for bandwidth usage
echo "show table api_key_bandwidth_out" | docker exec -i haproxy1 socat stdio /tmp/haproxy.sock
echo "show table api_key_bandwidth_in" | docker exec -i haproxy1 socat stdio /tmp/haproxy.sock
```

### View HAProxy Logs for Bandwidth Events
```bash
# Monitor HAProxy logs for bandwidth limiting events
docker logs -f haproxy1 | grep -i "bandwidth\|bwlim"

# Check Lua debug messages for bandwidth calculations
docker logs haproxy1 | grep "API Key.*bytes/s"
```

### Validate Configuration
```bash
# Test HAProxy configuration syntax
docker exec haproxy1 haproxy -f /usr/local/etc/haproxy/haproxy.cfg -c

# Validate all map files
./scripts/manage-dynamic-limits validate

# Check that bandwidth map files are loaded
echo "show map" | docker exec -i haproxy1 socat stdio /tmp/haproxy.sock | grep bandwidth
```

## Expected Results

### Performance Expectations
Based on the configured limits:

| Tier | Expected Download Speed | Expected Upload Speed |
|------|------------------------|----------------------|
| Premium | ~50 MB/s | ~25 MB/s |
| Standard | ~10 MB/s | ~5 MB/s |
| Basic | ~2 MB/s | ~1 MB/s |  
| Default | ~1 MB/s | ~512 KB/s |

### Response Headers
Every response should include:
- `X-Bandwidth-Limit-Download`: Download limit in bytes/s
- `X-Bandwidth-Limit-Upload`: Upload limit in bytes/s  
- `X-Bandwidth-Current-Download`: Current download usage
- `X-Bandwidth-Current-Upload`: Current upload usage
- Existing rate limit headers (unchanged)

### Error Conditions
- API keys without bandwidth limits configured should use default limits
- Invalid bandwidth unit formats should be rejected by management script
- Bandwidth limiting should work independently of request rate limiting
- Both types of limits can be triggered simultaneously

## Performance Regression Testing

### Baseline Performance (Before Bandwidth Limiting)
```bash
# Test with bandwidth limiting disabled (comment out filters in HAProxy config)
# Record baseline performance metrics
```

### With Bandwidth Limiting Enabled  
```bash
# Compare performance to ensure minimal overhead
# Bandwidth limiting should not impact performance when limits are not reached
```

## Integration with Existing Tests

### Update Rate Limit Test Suite
The existing test suite in `cmd/ratelimit-test/` should be updated to:

1. **Test bandwidth headers presence**
2. **Validate bandwidth limit values match configuration**  
3. **Test bandwidth throttling behavior**
4. **Ensure request and bandwidth limits work together**

### New Test Categories
- **Bandwidth threshold testing**: Verify limits are enforced
- **Multi-tier bandwidth testing**: Compare speeds across tiers
- **Hot reload testing**: Verify bandwidth limits update without restart
- **Error handling**: Test invalid configurations and edge cases

---

## Troubleshooting Common Issues

### Bandwidth Limiting Not Working
1. Check HAProxy configuration syntax
2. Verify bandwidth map files exist and are readable
3. Confirm API key is mapped to a group with bandwidth limits
4. Check HAProxy logs for filter errors

### Performance Issues
1. Monitor system resources (CPU, memory)
2. Check stick table sizes and expiry settings
3. Verify bandwidth limits are realistic for hardware
4. Monitor HAProxy stats for bottlenecks

### Configuration Errors
1. Validate map file formats
2. Test hot reload functionality
3. Check socket permissions for runtime API
4. Verify backup and restore functions

This testing guide ensures comprehensive validation of the bandwidth-based rate limiting implementation while maintaining compatibility with existing request-based rate limiting features.