#!/bin/bash

# Setup Environment Script for HAProxy MinIO Rate Limiting
# This script:
# 1. Generates SSL certificates
# 2. Adds them to the macOS trust chain
# 3. Rebuilds Docker containers

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$SCRIPT_DIR/.."

echo "🚀 Setting up HAProxy MinIO Rate Limiting Environment"
echo "===================================================="
echo ""

# First, generate SSL certificates
echo "Step 1: Generating SSL certificates"
echo "-----------------------------"
$SCRIPT_DIR/generate-ssl-haproxy-certificates.sh

# Now rebuild the Docker containers
echo ""
echo "Step 2: Rebuilding Docker containers"
echo "-----------------------------"
cd $PROJECT_DIR
docker-compose down
docker-compose build --no-cache haproxy1 haproxy2
docker-compose up -d

echo ""
echo "✅ Environment setup complete!"
echo ""
echo "You can access the services at:"
echo "  - HAProxy 1: https://localhost:443"
echo "  - HAProxy 2: https://localhost:444"
echo "  - MinIO Console: http://localhost:9091"
echo ""
echo "Note: Your browser should now trust the SSL certificate."
echo "If you still see certificate warnings, you may need to restart your browser."
