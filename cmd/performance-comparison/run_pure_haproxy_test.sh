#!/bin/bash

# Pure HAProxy Latency Test
# Tests HAProxy response times without any backend calls

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Pure HAProxy Latency Analysis${NC}"
echo -e "${BLUE}===================================${NC}"
echo ""

# Step 1: Ensure we're in the right directory
cd "$PROJECT_ROOT"

echo -e "${YELLOW}📋 Pre-test Setup${NC}"

# Step 2: Start Pure HAProxy test container
echo ""
echo -e "${YELLOW}🔧 Setting up Pure HAProxy test container...${NC}"

# Create pure HAProxy container with multiple test endpoints
docker run -d \
    --name haproxy-pure-test \
    --network minio-ratelimit_default \
    -p 8081:8081 \
    -p 8082:8082 \
    -p 8083:8083 \
    -p 8407:8407 \
    -v "$SCRIPT_DIR/haproxy_pure_test.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro" \
    -v "$PROJECT_ROOT/extract_api_keys.lua:/usr/local/etc/haproxy/extract_api_keys.lua:ro" \
    -v "$PROJECT_ROOT/dynamic_rate_limiter.lua:/usr/local/etc/haproxy/dynamic_rate_limiter.lua:ro" \
    -v "$PROJECT_ROOT/config:/usr/local/etc/haproxy/config:ro" \
    haproxy:3.0 2>/dev/null || {
    echo -e "${YELLOW}⚠️ Container already exists, restarting...${NC}"
    docker stop haproxy-pure-test 2>/dev/null || true
    docker rm haproxy-pure-test 2>/dev/null || true
    docker run -d \
        --name haproxy-pure-test \
        --network minio-ratelimit_default \
        -p 8081:8081 \
        -p 8082:8082 \
        -p 8083:8083 \
        -p 8407:8407 \
        -v "$SCRIPT_DIR/haproxy_pure_test.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro" \
        -v "$PROJECT_ROOT/extract_api_keys.lua:/usr/local/etc/haproxy/extract_api_keys.lua:ro" \
        -v "$PROJECT_ROOT/dynamic_rate_limiter.lua:/usr/local/etc/haproxy/dynamic_rate_limiter.lua:ro" \
        -v "$PROJECT_ROOT/config:/usr/local/etc/haproxy/config:ro" \
        haproxy:3.0
}

echo "• Waiting for Pure HAProxy test container to be ready..."
sleep 5

# Verify all test endpoints are responding
echo "• Testing Pure HAProxy with rate limiting (port 8081)..."
if curl -s -f -H "Authorization: AWS test-basic-1:signature" -H "Date: $(date -u)" \
   "http://localhost:8081/test-bucket/test-object.txt" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Pure HAProxy with rate limiting is responding${NC}"
else
    echo -e "${YELLOW}⚠️ Pure HAProxy with rate limiting response check${NC}"
fi

echo "• Testing Pure HAProxy without rate limiting (port 8082)..."
if curl -s -f -H "Authorization: AWS test-basic-1:signature" -H "Date: $(date -u)" \
   "http://localhost:8082/test-bucket/test-object.txt" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Pure HAProxy without rate limiting is responding${NC}"
else
    echo -e "${YELLOW}⚠️ Pure HAProxy without rate limiting response check${NC}"
fi

echo "• Testing Minimal HAProxy (port 8083)..."
if curl -s -f "http://localhost:8083/test-bucket/test-object.txt" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Minimal HAProxy is responding${NC}"
else
    echo -e "${YELLOW}⚠️ Minimal HAProxy response check${NC}"
fi

# Step 3: Run the pure HAProxy latency tests
echo ""
echo -e "${YELLOW}🧪 Running Pure HAProxy Latency Tests${NC}"

cd "$SCRIPT_DIR"

# Download dependencies
echo "• Installing Go dependencies..."
go mod tidy > /dev/null 2>&1

echo "• Running pure HAProxy latency analysis..."
echo ""

# Run the actual performance test
go run pure_haproxy_latency.go

# Step 4: Show a sample response to verify everything works
echo ""
echo -e "${YELLOW}📋 Sample Response Verification${NC}"

echo "• Sample response from HAProxy with rate limiting:"
curl -s -H "Authorization: AWS 5HQZO7EDOM4XBNO642GQ:$(echo -n "GET\n\n\n$(date -u)\n/test-bucket/test-object.txt" | openssl dgst -sha1 -hmac "Ct4GdhfwRbLqb+J6ckrtJw+wlWgrImTDuoRjId2Q" -binary | base64)" -H "Date: $(date -u)" "http://localhost:8081/test-bucket/test-object.txt" -i | head -20

# Step 5: Cleanup
echo ""
echo -e "${YELLOW}🧹 Cleaning up...${NC}"

echo "• Stopping Pure HAProxy test container..."
docker stop haproxy-pure-test > /dev/null 2>&1
docker rm haproxy-pure-test > /dev/null 2>&1

echo -e "${GREEN}✅ Cleanup completed${NC}"

echo ""
echo -e "${BLUE}🎯 Pure HAProxy latency analysis completed!${NC}"
echo ""
echo -e "${YELLOW}📊 Key Benefits of this test:${NC}"
echo "• Isolates pure HAProxy latency (no MinIO backend)"
echo "• Measures exact overhead of each component:"
echo "  - Minimal HAProxy (baseline)"
echo "  - + Auth parsing overhead"
echo "  - + Rate limiting overhead"
echo "• Provides accurate performance optimization targets"