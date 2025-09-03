#!/bin/bash

# HAProxy Rate Limiting Performance Comparison Test
# This script runs performance tests comparing HAProxy with and without rate limiting

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 HAProxy Rate Limiting Performance Comparison${NC}"
echo -e "${BLUE}===============================================${NC}"
echo ""

# Step 1: Ensure we're in the right directory and services are running
cd "$PROJECT_ROOT"

echo -e "${YELLOW}📋 Pre-test Setup${NC}"
echo "• Checking Docker Compose services..."

if ! docker-compose ps | grep -q "Up"; then
    echo -e "${RED}❌ Services not running. Starting services...${NC}"
    docker-compose up -d
    echo "• Waiting for services to be ready..."
    sleep 10
fi

echo -e "${GREEN}✅ Services are running${NC}"

# Step 2: Start HAProxy instance WITHOUT rate limiting
echo ""
echo -e "${YELLOW}🔧 Setting up HAProxy without rate limiting...${NC}"

# Create temporary HAProxy container without rate limiting
docker run -d \
    --name haproxy-no-rate-limiting \
    --network minio-ratelimit_default \
    -p 8080:8080 \
    -p 8406:8406 \
    -v "$SCRIPT_DIR/haproxy_no_rate_limiting.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro" \
    -v "$PROJECT_ROOT/extract_api_keys.lua:/usr/local/etc/haproxy/extract_api_keys.lua:ro" \
    -v "$PROJECT_ROOT/config:/usr/local/etc/haproxy/config:ro" \
    haproxy:3.0 2>/dev/null || {
    echo -e "${YELLOW}⚠️ Container already exists, restarting...${NC}"
    docker stop haproxy-no-rate-limiting 2>/dev/null || true
    docker rm haproxy-no-rate-limiting 2>/dev/null || true
    docker run -d \
        --name haproxy-no-rate-limiting \
        --network minio-ratelimit_default \
        -p 8080:8080 \
        -p 8406:8406 \
        -v "$SCRIPT_DIR/haproxy_no_rate_limiting.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro" \
        -v "$PROJECT_ROOT/extract_api_keys.lua:/usr/local/etc/haproxy/extract_api_keys.lua:ro" \
        -v "$PROJECT_ROOT/config:/usr/local/etc/haproxy/config:ro" \
        haproxy:3.0
}

echo "• Waiting for HAProxy (no rate limiting) to be ready..."
sleep 5

# Verify both HAProxy instances are responding
echo "• Testing HAProxy with rate limiting (port 80)..."
if curl -s -f -H "Authorization: AWS test-basic-1:signature" -H "Date: $(date -u)" \
   "http://localhost:80/test-bucket/" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ HAProxy with rate limiting is responding${NC}"
else
    echo -e "${YELLOW}⚠️ HAProxy with rate limiting response (expected - bucket may not exist)${NC}"
fi

echo "• Testing HAProxy without rate limiting (port 8080)..."
if curl -s -f -H "Authorization: AWS test-basic-1:signature" -H "Date: $(date -u)" \
   "http://localhost:8080/test-bucket/" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ HAProxy without rate limiting is responding${NC}"
else
    echo -e "${YELLOW}⚠️ HAProxy without rate limiting response (expected - bucket may not exist)${NC}"
fi

# Step 3: Run the performance tests
echo ""
echo -e "${YELLOW}🧪 Running Performance Tests${NC}"

cd "$SCRIPT_DIR"

# Download dependencies
echo "• Installing Go dependencies..."
go mod tidy > /dev/null 2>&1

echo "• Running performance comparison..."
echo ""

# Run the actual performance test
go run realistic_performance.go

# Step 4: Cleanup
echo ""
echo -e "${YELLOW}🧹 Cleaning up...${NC}"

echo "• Stopping HAProxy without rate limiting..."
docker stop haproxy-no-rate-limiting > /dev/null 2>&1
docker rm haproxy-no-rate-limiting > /dev/null 2>&1

echo -e "${GREEN}✅ Cleanup completed${NC}"

echo ""
echo -e "${BLUE}🎯 Performance comparison test completed!${NC}"
echo ""
echo -e "${YELLOW}📊 Key Takeaways:${NC}"
echo "• The test compares HAProxy with full rate limiting vs HAProxy with no rate limiting"
echo "• Both scenarios use the same authentication extraction and backend routing"
echo "• Rate limiting overhead includes: Lua script execution, stick table lookups, and dynamic comparisons"
echo "• Results show the pure overhead cost of the dynamic rate limiting system"