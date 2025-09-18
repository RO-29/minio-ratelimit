# Bandwidth-Based Rate Limiting Implementation Plan

## Executive Summary

This document outlines the implementation plan for adding **bandwidth-based rate limiting** (bytes per second) to the existing MinIO S3 API rate limiting system. The solution leverages HAProxy 3.0's native bandwidth limiting capabilities while maintaining full compatibility with the current group-based, hot-reloadable architecture.

**Key Finding**: HAProxy 3.0's `bwlim-in` and `bwlim-out` filters can be seamlessly integrated with the existing request-based rate limiting system to provide dual-layer protection.

---

## Current Architecture Analysis

### Existing Implementation
The repository currently implements:

- **Request-based rate limiting**: Requests per minute/second using HAProxy stick tables
- **Dynamic group-based system**: API key → group mapping with 4 tiers (premium, standard, basic, default)
- **Hot-reloadable configuration**: Runtime updates via HAProxy map files
- **Lua-based processing**: Advanced S3 authentication extraction and rate limit checks
- **Individual API key tracking**: Each API key maintains separate rate counters
- **Multi-authentication support**: AWS Signature V2/V4, pre-signed URLs, custom headers

### Current Rate Limits (Request-Based)

| Tier | Per-Minute Limit | Per-Second Burst |
|------|------------------|------------------|
| Premium | 5,000 requests | 50 requests |
| Standard | 1,000 requests | 25 requests |
| Basic | 100 requests | 10 requests |
| Default | 50 requests | 5 requests |

---

## HAProxy 3.0 Bandwidth Limiting Research

### Key Capabilities Discovered

1. **Native Bandwidth Filters**:
   - `bwlim-in`: Controls incoming bandwidth (upload speed)
   - `bwlim-out`: Controls outgoing bandwidth (download speed)
   - Limits expressed in bytes per second with unit support (K, M, G)

2. **Per-Stream Limiting**:
   - Applied per HTTP stream, not per connection
   - Works with HTTP/2 multiplexed connections
   - Each stream gets individual bandwidth quota

3. **Stick Table Integration**:
   - Can track `bytes_in_rate(1s)` and `bytes_out_rate(1s)`
   - Per-API-key bandwidth usage monitoring
   - Automatic cleanup with configurable expiry

4. **Dynamic Control**:
   - Filters can be enabled/disabled conditionally
   - Limits can be set per request based on variables
   - Full integration with HAProxy's runtime API

### Unit Specifications
- **Bytes**: Default unit (raw numbers)
- **K**: Kilobytes (1024 bytes)
- **M**: Megabytes (1,048,576 bytes)
- **G**: Gigabytes (1,073,741,824 bytes)

---

## Implementation Plan

### Phase 1: HAProxy Configuration Updates

#### 1.1 Frontend Filter Definitions

Add bandwidth limiting filters to `haproxy/haproxy.cfg`:

```haproxy
frontend s3_frontend_optimized
    bind *:80
    bind *:443 ssl crt /etc/ssl/certs/haproxy.pem

    # Existing request rate limiting (maintain as-is)
    http-request lua.extract_api_key
    http-request set-var(txn.rate_group) var(txn.api_key),map(/usr/local/etc/haproxy/config/api_key_groups.map,default)

    # NEW: Dynamic bandwidth limit loading
    http-request set-var(txn.bw_download_limit) var(txn.rate_group),map(/usr/local/etc/haproxy/config/bandwidth_limits_download.map,524288) if { var(txn.api_key) -m found }
    http-request set-var(txn.bw_upload_limit) var(txn.rate_group),map(/usr/local/etc/haproxy/config/bandwidth_limits_upload.map,262144) if { var(txn.api_key) -m found }

    # NEW: Bandwidth limiting filters with per-API-key tracking
    filter bwlim-out download_bw key var(txn.api_key) table api_key_bandwidth_out limit var(txn.bw_download_limit)
    filter bwlim-in upload_bw key var(txn.api_key) table api_key_bandwidth_in limit var(txn.bw_upload_limit)

    # Enable bandwidth filters conditionally
    http-response set-bandwidth-limit download_bw if { var(txn.api_key) -m found } { var(txn.api_key) -m len 1: }
    http-request set-bandwidth-limit upload_bw if { var(txn.api_key) -m found } { var(txn.api_key) -m len 1: }

    # Enhanced response headers
    http-response set-header X-Bandwidth-Limit-Download "%[var(txn.bw_download_limit)]" if { var(txn.bw_download_limit) -m found }
    http-response set-header X-Bandwidth-Limit-Upload "%[var(txn.bw_upload_limit)]" if { var(txn.bw_upload_limit) -m found }
    http-response set-header X-Bandwidth-Current-Download "%[sc_bytes_out_rate(0)]" if { method PUT GET }
    http-response set-header X-Bandwidth-Current-Upload "%[sc_bytes_in_rate(0)]" if { method PUT GET }

    default_backend minio_backend
```

#### 1.2 New Stick Tables for Bandwidth Tracking

```haproxy
# Bandwidth tracking stick tables
backend api_key_bandwidth_out
    stick-table type string len 32 size 50k expire 300s store bytes_out_rate(1s),bytes_out_cnt

backend api_key_bandwidth_in
    stick-table type string len 32 size 50k expire 300s store bytes_in_rate(1s),bytes_in_cnt
```

### Phase 2: Configuration Map Files

#### 2.1 Download Bandwidth Limits Map

**File**: `haproxy/config/bandwidth_limits_download.map`
```
# Group -> Download limit in bytes per second
premium 10485760     # 10 MB/s
standard 5242880     # 5 MB/s
basic 1048576        # 1 MB/s
default 524288       # 512 KB/s
```

#### 2.2 Upload Bandwidth Limits Map

**File**: `haproxy/config/bandwidth_limits_upload.map`
```
# Group -> Upload limit in bytes per second
premium 5242880      # 5 MB/s
standard 2097152     # 2 MB/s
basic 524288         # 512 KB/s
default 262144       # 256 KB/s
```

### Phase 3: Lua Script Enhancements

#### 3.1 Bandwidth Limit Processing

Add to `haproxy/lua/dynamic_rate_limiter.lua`:

```lua
-- Bandwidth limiting function
function check_bandwidth_limits(txn)
    local api_key = txn:get_var("txn.api_key")
    
    -- Skip bandwidth limiting for empty API keys
    if not api_key or api_key == "" then
        return
    end
    
    -- Get current bandwidth usage from stick tables
    local current_download = tonumber(txn.sf:sc_bytes_out_rate(0)) or 0
    local current_upload = tonumber(txn.sf:sc_bytes_in_rate(0)) or 0
    
    -- Get bandwidth limits
    local download_limit = tonumber(txn:get_var("txn.bw_download_limit")) or 524288
    local upload_limit = tonumber(txn:get_var("txn.bw_upload_limit")) or 262144
    
    -- Set variables for response headers
    txn:set_var("txn.current_download_bw", tostring(current_download))
    txn:set_var("txn.current_upload_bw", tostring(current_upload))
    
    -- Optional: Log bandwidth usage for monitoring
    core.Debug(string.format("API Key: %s, Download: %d/%d bytes/s, Upload: %d/%d bytes/s", 
                            api_key, current_download, download_limit, current_upload, upload_limit))
end

-- Register the function
core.register_action("check_bandwidth_limits", {"http-req"}, check_bandwidth_limits, 0)
```

### Phase 4: Management Script Extensions

#### 4.1 Enhanced `scripts/manage-dynamic-limits`

Add bandwidth management functions:

```bash
#!/bin/bash

# Existing functions remain unchanged...

# NEW: Bandwidth limit management functions
set_download_limit() {
    local group=$1
    local limit_bytes=$2
    
    if [[ ! "$limit_bytes" =~ ^[0-9]+$ ]]; then
        limit_bytes=$(convert_to_bytes "$limit_bytes")
    fi
    
    echo "set map /usr/local/etc/haproxy/config/bandwidth_limits_download.map $group $limit_bytes" | \
        socat stdio unix-connect:/tmp/haproxy.sock
    
    echo "✅ Set download limit for $group to $limit_bytes bytes/s"
}

set_upload_limit() {
    local group=$1
    local limit_bytes=$2
    
    if [[ ! "$limit_bytes" =~ ^[0-9]+$ ]]; then
        limit_bytes=$(convert_to_bytes "$limit_bytes")
    fi
    
    echo "set map /usr/local/etc/haproxy/config/bandwidth_limits_upload.map $group $limit_bytes" | \
        socat stdio unix-connect:/tmp/haproxy.sock
    
    echo "✅ Set upload limit for $group to $limit_bytes bytes/s"
}

get_bandwidth_limits() {
    local group=$1
    echo "📊 Bandwidth limits for group: $group"
    echo "Download: $(grep "^$group " haproxy/config/bandwidth_limits_download.map | cut -d' ' -f2) bytes/s"
    echo "Upload: $(grep "^$group " haproxy/config/bandwidth_limits_upload.map | cut -d' ' -f2) bytes/s"
}

convert_to_bytes() {
    local value=$1
    local num unit
    
    # Extract number and unit
    if [[ $value =~ ^([0-9]+)([KMG]?)B?$ ]]; then
        num=${BASH_REMATCH[1]}
        unit=${BASH_REMATCH[2]}
        
        case $unit in
            "K") echo $((num * 1024)) ;;
            "M") echo $((num * 1048576)) ;;
            "G") echo $((num * 1073741824)) ;;
            "") echo $num ;;  # No unit, assume bytes
            *) echo "❌ Invalid unit: $unit" >&2; return 1 ;;
        esac
    else
        echo "❌ Invalid format: $value" >&2
        return 1
    fi
}

show_bandwidth_config() {
    echo "🌐 BANDWIDTH RATE LIMITS CONFIGURATION"
    echo "======================================="
    echo ""
    echo "📥 DOWNLOAD LIMITS:"
    cat haproxy/config/bandwidth_limits_download.map | while read group limit; do
        [[ -z "$group" || "$group" =~ ^# ]] && continue
        echo "  $group: $(format_bytes $limit)"
    done
    echo ""
    echo "📤 UPLOAD LIMITS:"
    cat haproxy/config/bandwidth_limits_upload.map | while read group limit; do
        [[ -z "$group" || "$group" =~ ^# ]] && continue
        echo "  $group: $(format_bytes $limit)"
    done
}

format_bytes() {
    local bytes=$1
    if (( bytes >= 1073741824 )); then
        echo "$((bytes / 1073741824)) GB/s"
    elif (( bytes >= 1048576 )); then
        echo "$((bytes / 1048576)) MB/s"
    elif (( bytes >= 1024 )); then
        echo "$((bytes / 1024)) KB/s"
    else
        echo "$bytes bytes/s"
    fi
}

# Update usage function
usage() {
    echo "MinIO Dynamic Rate Limiting Management Script"
    echo "============================================="
    echo ""
    echo "REQUEST-BASED RATE LIMITING:"
    echo "  show-config                          Show current configuration"
    echo "  add-key <api_key> <group>           Add API key to group"
    echo "  remove-key <api_key>                Remove API key"
    echo "  update-key <api_key> <group>        Update API key group"
    echo "  set-limits <group> <per_min> <per_sec>  Set request limits"
    echo ""
    echo "BANDWIDTH-BASED RATE LIMITING:"
    echo "  set-download-limit <group> <bytes_or_unit>  Set download bandwidth limit"
    echo "  set-upload-limit <group> <bytes_or_unit>    Set upload bandwidth limit"
    echo "  get-bandwidth-limits <group>               Get bandwidth limits for group"
    echo "  show-bandwidth-config                      Show all bandwidth limits"
    echo ""
    echo "SYSTEM MANAGEMENT:"
    echo "  backup                              Create configuration backup"
    echo "  restore <backup_file>              Restore from backup"
    echo "  reload                             Hot reload HAProxy configuration"
    echo "  validate                           Validate all map files"
    echo ""
    echo "Examples:"
    echo "  $0 set-download-limit premium 50M      # 50 MB/s download limit"
    echo "  $0 set-upload-limit standard 10MB      # 10 MB/s upload limit"
    echo "  $0 set-download-limit basic 2048000    # 2048000 bytes/s download limit"
}

# Add new cases to the main script logic
case "$1" in
    "set-download-limit")
        [[ $# -ne 3 ]] && { echo "Usage: $0 set-download-limit <group> <bytes_or_unit>"; exit 1; }
        set_download_limit "$2" "$3"
        ;;
    "set-upload-limit")
        [[ $# -ne 3 ]] && { echo "Usage: $0 set-upload-limit <group> <bytes_or_unit>"; exit 1; }
        set_upload_limit "$2" "$3"
        ;;
    "get-bandwidth-limits")
        [[ $# -ne 2 ]] && { echo "Usage: $0 get-bandwidth-limits <group>"; exit 1; }
        get_bandwidth_limits "$2"
        ;;
    "show-bandwidth-config")
        show_bandwidth_config
        ;;
    # ... existing cases remain unchanged
esac
```

### Phase 5: Testing Framework Updates

#### 5.1 Bandwidth Testing Integration

Add to `cmd/ratelimit-test/main.go`:

```go
// Add bandwidth testing capabilities
type BandwidthTestResult struct {
    APIKey           string        `json:"api_key"`
    Group            string        `json:"group"`
    UploadSpeed      float64       `json:"upload_speed_bytes_sec"`
    DownloadSpeed    float64       `json:"download_speed_bytes_sec"`
    UploadLimit      int64         `json:"upload_limit_bytes_sec"`
    DownloadLimit    int64         `json:"download_limit_bytes_sec"`
    UploadThrottled  bool          `json:"upload_throttled"`
    DownloadThrottled bool         `json:"download_throttled"`
    TestDuration     time.Duration `json:"test_duration"`
}

func testBandwidthLimits(apiKey, group string) BandwidthTestResult {
    // Implementation for bandwidth testing
    // Upload large file to measure upload speed
    // Download large file to measure download speed
    // Compare against expected limits from response headers
    
    result := BandwidthTestResult{
        APIKey: apiKey,
        Group:  group,
    }
    
    // Test upload bandwidth
    uploadStart := time.Now()
    uploadResp := uploadLargeFile(apiKey, "bandwidth-test-upload", 10*1024*1024) // 10MB
    uploadDuration := time.Since(uploadStart)
    
    if uploadResp != nil {
        result.UploadSpeed = float64(10*1024*1024) / uploadDuration.Seconds()
        result.UploadLimit = parseHeaderInt64(uploadResp.Header.Get("X-Bandwidth-Limit-Upload"))
        result.UploadThrottled = result.UploadSpeed < float64(result.UploadLimit) * 0.8 // Within 80% suggests throttling
    }
    
    // Test download bandwidth
    downloadStart := time.Now()
    downloadResp := downloadLargeFile(apiKey, "bandwidth-test-download")
    downloadDuration := time.Since(downloadStart)
    
    if downloadResp != nil {
        // Estimate download size from Content-Length or measure actual bytes
        downloadSize := parseHeaderInt64(downloadResp.Header.Get("Content-Length"))
        result.DownloadSpeed = float64(downloadSize) / downloadDuration.Seconds()
        result.DownloadLimit = parseHeaderInt64(downloadResp.Header.Get("X-Bandwidth-Limit-Download"))
        result.DownloadThrottled = result.DownloadSpeed < float64(result.DownloadLimit) * 0.8
    }
    
    result.TestDuration = uploadDuration + downloadDuration
    return result
}
```

---

## Proposed Bandwidth Limits by Tier

### Recommended Initial Settings

| Tier | Download Limit | Upload Limit | Use Case |
|------|----------------|--------------|----------|
| **Premium** | 50 MB/s | 25 MB/s | High-volume production applications |
| **Standard** | 10 MB/s | 5 MB/s | Standard production workloads |
| **Basic** | 2 MB/s | 1 MB/s | Development and testing |
| **Default** | 1 MB/s | 512 KB/s | Unknown/unclassified API keys |

### Rationale
- **Premium tier**: Generous limits for paying customers with high-bandwidth needs
- **Standard tier**: Balanced limits for typical production usage
- **Basic tier**: Sufficient for development but prevents abuse
- **Default tier**: Conservative limits for unknown API keys

---

## Integration Benefits

### 1. **Dual-Layer Protection**
- **Request-based limits**: Prevent API abuse and excessive request volume
- **Bandwidth-based limits**: Prevent bandwidth abuse and ensure fair resource sharing
- **Independent operation**: Each limit type works independently - either can trigger

### 2. **Consistent Architecture**
- **Same group-based system**: Both limit types use identical API key → group mapping
- **Hot-reloadable**: All bandwidth limits changeable without HAProxy restart
- **Same management interface**: Single script manages both request and bandwidth limits
- **Unified monitoring**: Both limit types exposed via response headers and stats

### 3. **S3 Compatibility**
- **All authentication methods**: Works with AWS V2/V4, pre-signed URLs, custom headers
- **Per-API-key tracking**: Each API key gets individual bandwidth quotas
- **Stream-level limiting**: Works correctly with HTTP/2 multiplexed connections
- **S3 error format**: Bandwidth limit violations can return S3-compatible error responses

### 4. **Performance Optimized**
- **Native HAProxy filters**: Uses HAProxy's optimized bandwidth limiting code
- **Conditional processing**: Bandwidth limiting only applied when API key present
- **Efficient tracking**: Stick tables provide fast, memory-based bandwidth monitoring
- **Early exit paths**: Minimal performance impact on non-limited requests

---

## Migration Strategy

### Phase 1: Development Setup (Week 1)
1. Update HAProxy configuration with bandwidth filters
2. Create initial bandwidth limit map files
3. Extend management script with bandwidth functions
4. Test in development environment

### Phase 2: Testing & Validation (Week 2)
1. Extend test suite with bandwidth testing
2. Validate bandwidth limiting across all authentication methods
3. Performance testing to ensure no regression
4. Document bandwidth limit behaviors

### Phase 3: Production Deployment (Week 3)
1. Deploy with conservative initial limits
2. Monitor bandwidth usage patterns
3. Gradually optimize limits based on usage data
4. Create operational runbooks for bandwidth management

### Phase 4: Optimization (Week 4)
1. Fine-tune limits based on production data
2. Implement advanced bandwidth policies if needed
3. Add alerting for bandwidth limit violations
4. Document best practices and troubleshooting guides

---

## Usage Examples

### Setting Bandwidth Limits
```bash
# Set premium tier bandwidth limits
./scripts/manage-dynamic-limits set-download-limit premium 50M
./scripts/manage-dynamic-limits set-upload-limit premium 25M

# Set basic tier with explicit bytes
./scripts/manage-dynamic-limits set-download-limit basic 2097152
./scripts/manage-dynamic-limits set-upload-limit basic 1048576

# View current bandwidth configuration
./scripts/manage-dynamic-limits show-bandwidth-config

# Get specific group's bandwidth limits
./scripts/manage-dynamic-limits get-bandwidth-limits standard
```

### Expected Response Headers
```http
HTTP/1.1 200 OK
X-RateLimit-Group: premium
X-RateLimit-Limit-Per-Minute: 5000
X-RateLimit-Limit-Per-Second: 50
X-Bandwidth-Limit-Download: 52428800
X-Bandwidth-Limit-Upload: 26214400
X-Bandwidth-Current-Download: 15728640
X-Bandwidth-Current-Upload: 5242880
X-API-Key: 5HQZO7EDOM4XBNO642GQ
X-Auth-Method: v4_header_lua
```

### Testing Bandwidth Limits
```bash
# Run bandwidth test for specific API key
curl -X PUT http://localhost/test-bucket/large-file \
  -H "Authorization: AWS4-HMAC-SHA256 Credential=PREMIUMKEY/..." \
  -H "Content-Type: application/octet-stream" \
  --data-binary @10MB_test_file.bin \
  -w "Upload time: %{time_total}s, Speed: %{speed_upload} bytes/s\n"
```

---

## Monitoring and Alerting

### Key Metrics to Track
1. **Bandwidth utilization per API key**: Track against limits
2. **Throttling events**: Count of bandwidth-limited requests  
3. **Top bandwidth consumers**: Identify heavy users
4. **Group-level bandwidth usage**: Aggregate consumption by tier
5. **Bandwidth vs request limiting**: Which limit triggers more often

### HAProxy Stats Integration
- Bandwidth stick tables visible in stats interface
- Per-API-key bandwidth rates and counters
- Real-time bandwidth usage monitoring
- Historical bandwidth data (limited by stick table expiry)

### Alerting Scenarios
- API key consistently hitting bandwidth limits
- Unusual bandwidth spikes from specific keys
- Group-level bandwidth consumption exceeding thresholds
- Bandwidth limiting causing high error rates

---

## Conclusion

The implementation plan leverages HAProxy 3.0's native bandwidth limiting capabilities while maintaining full compatibility with the existing architecture. The dual-layer approach (request + bandwidth limiting) provides comprehensive protection against both API abuse and bandwidth abuse.

**Key Success Factors**:
1. **Maintains existing patterns**: Uses same group-based, hot-reloadable approach
2. **Non-disruptive**: Can be deployed alongside existing request limiting
3. **Fully integrated**: Single management interface for both limit types  
4. **Production-ready**: Builds on proven HAProxy 3.0 bandwidth limiting features
5. **Highly configurable**: Per-tier bandwidth limits with easy adjustment

This approach ensures that the MinIO S3 API rate limiting system can effectively control both request volume and bandwidth consumption while maintaining the flexibility and operational simplicity that characterizes the current implementation.