#!/bin/bash

# HAProxy Optimization Performance Comparison
# Tests original vs optimized rate limiting implementations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 HAProxy Optimization Performance Comparison${NC}"
echo -e "${BLUE}==============================================${NC}"
echo ""

# Step 1: Ensure we're in the right directory
cd "$PROJECT_ROOT"

echo -e "${YELLOW}📋 Pre-test Setup${NC}"

# Step 2: Start optimized HAProxy test container
echo ""
echo -e "${YELLOW}🔧 Setting up Optimized HAProxy test container...${NC}"

# Create optimized HAProxy container with test endpoints
docker run -d \
    --name haproxy-optimization-test \
    --network minio-ratelimit_default \
    -p 8081:8081 \
    -p 8083:8083 \
    -p 8084:8084 \
    -p 8408:8408 \
    -v "$SCRIPT_DIR/haproxy_pure_test_optimized.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro" \
    -v "$PROJECT_ROOT/extract_api_keys.lua:/usr/local/etc/haproxy/extract_api_keys.lua:ro" \
    -v "$PROJECT_ROOT/dynamic_rate_limiter.lua:/usr/local/etc/haproxy/dynamic_rate_limiter.lua:ro" \
    -v "$PROJECT_ROOT/extract_api_keys_optimized.lua:/usr/local/etc/haproxy/extract_api_keys_optimized.lua:ro" \
    -v "$PROJECT_ROOT/dynamic_rate_limiter_optimized.lua:/usr/local/etc/haproxy/dynamic_rate_limiter_optimized.lua:ro" \
    -v "$PROJECT_ROOT/config:/usr/local/etc/haproxy/config:ro" \
    haproxy:3.0 2>/dev/null || {
    echo -e "${YELLOW}⚠️ Container already exists, restarting...${NC}"
    docker stop haproxy-optimization-test 2>/dev/null || true
    docker rm haproxy-optimization-test 2>/dev/null || true
    docker run -d \
        --name haproxy-optimization-test \
        --network minio-ratelimit_default \
        -p 8081:8081 \
        -p 8083:8083 \
        -p 8084:8084 \
        -p 8408:8408 \
        -v "$SCRIPT_DIR/haproxy_pure_test_optimized.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro" \
        -v "$PROJECT_ROOT/extract_api_keys.lua:/usr/local/etc/haproxy/extract_api_keys.lua:ro" \
        -v "$PROJECT_ROOT/dynamic_rate_limiter.lua:/usr/local/etc/haproxy/dynamic_rate_limiter.lua:ro" \
        -v "$PROJECT_ROOT/extract_api_keys_optimized.lua:/usr/local/etc/haproxy/extract_api_keys_optimized.lua:ro" \
        -v "$PROJECT_ROOT/dynamic_rate_limiter_optimized.lua:/usr/local/etc/haproxy/dynamic_rate_limiter_optimized.lua:ro" \
        -v "$PROJECT_ROOT/config:/usr/local/etc/haproxy/config:ro" \
        haproxy:3.0
}

echo "• Waiting for Optimized HAProxy test container to be ready..."
sleep 5

# Verify all test endpoints are responding
echo "• Testing Minimal HAProxy (port 8083)..."
if curl -s -f "http://localhost:8083/test-bucket/test-object.txt" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Minimal HAProxy is responding${NC}"
else
    echo -e "${YELLOW}⚠️ Minimal HAProxy response check${NC}"
fi

echo "• Testing Original Rate Limiting HAProxy (port 8081)..."
if curl -s -H "Authorization: AWS test-basic-1:signature" -H "Date: $(date -u)" \
   "http://localhost:8081/test-bucket/test-object.txt" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Original Rate Limiting HAProxy is responding${NC}"
else
    echo -e "${YELLOW}⚠️ Original Rate Limiting HAProxy response check${NC}"
fi

echo "• Testing Optimized Rate Limiting HAProxy (port 8084)..."
if curl -s -H "Authorization: AWS test-basic-1:signature" -H "Date: $(date -u)" \
   "http://localhost:8084/test-bucket/test-object.txt" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Optimized Rate Limiting HAProxy is responding${NC}"
else
    echo -e "${YELLOW}⚠️ Optimized Rate Limiting HAProxy response check${NC}"
fi

# Step 3: Run the optimization comparison tests
echo ""
echo -e "${YELLOW}🧪 Running Optimization Performance Tests${NC}"

cd "$SCRIPT_DIR"

# Download dependencies
echo "• Installing Go dependencies..."
go mod tidy > /dev/null 2>&1

echo "• Running optimization comparison analysis..."
echo ""

# Run the actual performance test
go run optimized_comparison.go

# Step 4: Show sample responses from each endpoint
echo ""
echo -e "${YELLOW}📋 Sample Response Verification${NC}"

echo ""
echo "• Sample response from Original Rate Limiting:"
curl -s -H "Authorization: AWS 5HQZO7EDOM4XBNO642GQ:$(echo -n "GET\n\n\n$(date -u)\n/test-bucket/test-object.txt" | openssl dgst -sha1 -hmac "Ct4GdhfwRbLqb+J6ckrtJw+wlWgrImTDuoRjId2Q" -binary | base64)" -H "Date: $(date -u)" "http://localhost:8081/test-bucket/test-object.txt" -i | head -15

echo ""
echo "• Sample response from Optimized Rate Limiting:"
curl -s -H "Authorization: AWS 5HQZO7EDOM4XBNO642GQ:$(echo -n "GET\n\n\n$(date -u)\n/test-bucket/test-object.txt" | openssl dgst -sha1 -hmac "Ct4GdhfwRbLqb+J6ckrtJw+wlWgrImTDuoRjId2Q" -binary | base64)" -H "Date: $(date -u)" "http://localhost:8084/test-bucket/test-object.txt" -i | head -15

# Step 5: Cleanup
echo ""
echo -e "${YELLOW}🧹 Cleaning up...${NC}"

echo "• Stopping Optimized HAProxy test container..."
docker stop haproxy-optimization-test > /dev/null 2>&1
docker rm haproxy-optimization-test > /dev/null 2>&1

echo -e "${GREEN}✅ Cleanup completed${NC}"

echo ""
echo -e "${BLUE}🎯 Optimization performance comparison completed!${NC}"
echo ""
echo -e "${YELLOW}📊 Key Insights from this test:${NC}"
echo "• Compares three implementations: Minimal, Original, Optimized"
echo "• Measures exact performance improvements from optimizations"
echo "• Shows impact of Lua script optimizations and HAProxy tuning"
echo "• Provides concrete metrics for optimization effectiveness"
echo "• Validates optimization techniques in isolation"