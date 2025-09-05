#!/bin/bash
# Docker Compose Version Check
# This script detects the best Docker Compose command to use

# Function to print with/without colors
print_styled() {
  local color="$1"
  local message="$2"

  # Completely disable color in CI or when requested
  if [ -n "$CI" ] || [ -n "$CI_NO_COLOR" ] || [ -n "$NO_COLOR" ] || [ ! -t 1 ]; then
    printf "%s\n" "$message"
  else
    case "$color" in
      "red") printf "\033[0;31m%s\033[0m\n" "$message" ;;
      "green") printf "\033[0;32m%s\033[0m\n" "$message" ;;
      "yellow") printf "\033[0;33m%s\033[0m\n" "$message" ;;
      "blue") printf "\033[0;34m%s\033[0m\n" "$message" ;;
      *) printf "%s\n" "$message" ;;
    esac
  fi
}

print_styled "blue" "=== Checking Docker Compose Setup ==="

DOCKER_COMPOSE_FOUND=false

# Check for Docker first
if ! command -v docker &>/dev/null; then
    print_styled "red" "❌ Docker is not installed"
    print_styled "yellow" "Please install Docker before continuing"
    exit 1
fi

print_styled "green" "✅ Docker is installed: $(docker --version)"

# Check for Docker Compose v2 (Docker plugin)
if docker compose version &>/dev/null; then
    DOCKER_COMPOSE_VERSION=$(docker compose version | head -n 1)
    print_styled "green" "✅ Docker Compose v2 is available: $DOCKER_COMPOSE_VERSION"
    print_styled "blue" "Using command: docker compose"
    DOCKER_COMPOSE_CMD="docker compose"
    DOCKER_COMPOSE_FOUND=true
fi

# Check for Docker Compose v1 (standalone binary)
if command -v docker-compose &>/dev/null; then
    DOCKER_COMPOSE_VERSION=$(docker-compose --version | head -n 1)
    print_styled "green" "✅ Docker Compose v1 is installed: $DOCKER_COMPOSE_VERSION"

    if [ "$DOCKER_COMPOSE_FOUND" = false ]; then
        print_styled "blue" "Using command: docker-compose"
        DOCKER_COMPOSE_CMD="docker-compose"
        DOCKER_COMPOSE_FOUND=true
    else
        print_styled "yellow" "⚠️ Both Docker Compose v1 and v2 are installed"
        print_styled "yellow" "Using Docker Compose v2 by default: docker compose"
    fi
fi

# If no Docker Compose found
if [ "$DOCKER_COMPOSE_FOUND" = false ]; then
    print_styled "red" "❌ Docker Compose is not installed"
    print_styled "yellow" "Please install Docker Compose to use this project"
    exit 1
fi

# Save the command to a file for other scripts to use
echo "DOCKER_COMPOSE_CMD=\"$DOCKER_COMPOSE_CMD\"" > docker-compose-command.sh
chmod +x docker-compose-command.sh

print_styled "blue" "=== Docker Compose Command ==="
print_styled "green" "$DOCKER_COMPOSE_CMD"

# Example commands
print_styled "blue" "=== Example Commands ==="
print_styled "yellow" "Start services:     $DOCKER_COMPOSE_CMD up -d"
print_styled "yellow" "Check services:     $DOCKER_COMPOSE_CMD ps"
print_styled "yellow" "View logs:          $DOCKER_COMPOSE_CMD logs -f"
print_styled "yellow" "Stop services:      $DOCKER_COMPOSE_CMD down"

# Or use Make targets
print_styled "blue" "=== Or Use Make Targets ==="
print_styled "yellow" "Start services:     make up"
print_styled "yellow" "Check services:     make status"
print_styled "yellow" "View logs:          make logs"
print_styled "yellow" "Stop services:      make down"

exit 0
