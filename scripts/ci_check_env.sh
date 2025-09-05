#!/bin/bash
# CI Environment Verification
# This script checks for required tools in CI environments

set -e

echo "=== Checking CI Environment ==="

# Check Go version
if command -v go &> /dev/null; then
    GO_VERSION=$(go version)
    echo "✓ Go is installed: $GO_VERSION"
else
    echo "✗ Go is not installed"
    exit 1
fi

# Check for Docker
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo "✓ Docker is installed: $DOCKER_VERSION"
else
    echo "✗ Docker is not installed"
    exit 1
fi

# Check for Docker Compose v2 (Docker plugin)
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE_VERSION=$(docker compose version)
    echo "✓ Docker Compose v2 is available: $DOCKER_COMPOSE_VERSION"
    echo "Using command: docker compose"
    DOCKER_COMPOSE_CMD="docker compose"
    DOCKER_COMPOSE_FOUND=true
else
    echo "✗ Docker Compose v2 is not available"
fi

# Check for Docker Compose v1 (standalone binary)
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_VERSION=$(docker-compose --version)
    echo "✓ Docker Compose v1 is installed: $DOCKER_COMPOSE_VERSION"
    echo "Using command: docker-compose"
    if [ -z "$DOCKER_COMPOSE_CMD" ]; then
        DOCKER_COMPOSE_CMD="docker-compose"
        DOCKER_COMPOSE_FOUND=true
    fi
else
    echo "✗ Docker Compose v1 is not installed"
fi

# If no Docker Compose found, install it
if [ -z "$DOCKER_COMPOSE_FOUND" ]; then
    echo "Installing Docker Compose..."

    # Try installing docker-compose-plugin first (for v2)
    if apt-cache show docker-compose-plugin &>/dev/null; then
        sudo apt-get update
        sudo apt-get install -y docker-compose-plugin
        if docker compose version &>/dev/null; then
            echo "✓ Docker Compose v2 plugin installed: $(docker compose version)"
            DOCKER_COMPOSE_CMD="docker compose"
            DOCKER_COMPOSE_FOUND=true
        fi
    fi

    # If v2 failed, try installing standalone v1
    if [ -z "$DOCKER_COMPOSE_FOUND" ]; then
        sudo apt-get update
        sudo apt-get install -y docker-compose
        if docker-compose --version &>/dev/null; then
            echo "✓ Docker Compose v1 installed: $(docker-compose --version)"
            DOCKER_COMPOSE_CMD="docker-compose"
            DOCKER_COMPOSE_FOUND=true
        else
            echo "✗ Failed to install Docker Compose"
            echo "Will try using Docker directly for validation"
        fi
    fi
fi

# Check for HAProxy
if command -v haproxy &> /dev/null; then
    HAPROXY_VERSION=$(haproxy -v | head -n 1)
    echo "✓ HAProxy is installed: $HAPROXY_VERSION"
else
    echo "✗ HAProxy is not installed"
    echo "Installing HAProxy..."
    sudo apt-get update
    sudo apt-get install -y haproxy
    echo "✓ HAProxy installed: $(haproxy -v | head -n 1)"
fi

# Check for Lua
if command -v lua &> /dev/null; then
    LUA_VERSION=$(lua -v)
    echo "✓ Lua is installed: $LUA_VERSION"
else
    echo "✗ Lua is not installed"
    echo "Installing Lua..."
    sudo apt-get update
    sudo apt-get install -y lua5.3
    echo "✓ Lua installed: $(lua -v)"
fi

echo "=== CI Environment Check Complete ==="
echo "Docker Compose command to use: $DOCKER_COMPOSE_CMD"

# Create a file with the Docker Compose command for other scripts
echo "DOCKER_COMPOSE_CMD=\"$DOCKER_COMPOSE_CMD\"" > docker-compose-command.sh

# Success!
exit 0
