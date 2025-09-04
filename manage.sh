#!/bin/bash
# HAProxy MinIO Rate Limiter Management Script
# Usage: ./manage.sh [command]

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display help
function show_help() {
  echo -e "${BLUE}MinIO Rate Limiting with HAProxy - Management Script${NC}"
  echo ""
  echo "Usage: ./manage.sh [command]"
  echo ""
  echo "Commands:"
  echo "  up                - Start all services"
  echo "  down              - Stop all services"
  echo "  restart           - Restart all services"
  echo "  reload            - Reload HAProxy without downtime"
  echo "  logs              - View logs from all services"
  echo "  status            - Check service status"
  echo "  clean             - Clean up Docker resources"
  echo ""
  echo "HAProxy specific:"
  echo "  reload-haproxy    - Reload only HAProxy configs"
  echo "  haproxy-stats     - Open HAProxy stats in browser"
  echo "  test-limits       - Run a simple rate limit test"
  echo ""
  echo "Configuration management:"
  echo "  backup-configs    - Backup all configuration files"
  echo "  increase-limits   - Increase premium rate limits (specify amount as parameter)"
}

# Function to start all services
function start_services() {
  echo -e "${GREEN}Starting all services...${NC}"
  docker-compose up -d
  echo -e "${GREEN}Services started. HAProxy endpoints:${NC}"
  echo "  - Main: http://localhost:80"
  echo "  - Stats: http://localhost:8404/stats"
  echo "  - MinIO Console: http://localhost:9091"
}

# Function to stop all services
function stop_services() {
  echo -e "${YELLOW}Stopping all services...${NC}"
  docker-compose down
  echo -e "${YELLOW}Services stopped${NC}"
}

# Function to restart all services
function restart_services() {
  echo -e "${YELLOW}Restarting all services...${NC}"
  docker-compose restart
  echo -e "${GREEN}Services restarted${NC}"
}

# Function to reload HAProxy configuration
function reload_haproxy() {
  echo -e "${GREEN}Reloading HAProxy configuration without downtime...${NC}"
  echo -e "${BLUE}Reloading HAProxy 1...${NC}"
  docker-compose exec haproxy1 kill -SIGUSR2 1
  sleep 2
  echo -e "${BLUE}Reloading HAProxy 2...${NC}"
  docker-compose exec haproxy2 kill -SIGUSR2 1
  echo -e "${GREEN}HAProxy configuration reloaded${NC}"
}

# Function to view logs
function view_logs() {
  docker-compose logs -f
}

# Function to check status
function check_status() {
  docker-compose ps
}

# Function to clean up
function clean_up() {
  echo -e "${YELLOW}Cleaning up Docker resources...${NC}"
  docker-compose down -v --remove-orphans
  echo -e "${GREEN}Resources cleaned${NC}"
}

# Function to open HAProxy stats in browser
function open_haproxy_stats() {
  echo -e "${BLUE}Opening HAProxy stats in browser...${NC}"
  open http://localhost:8404/stats
}

# Function to test rate limits
function test_rate_limits() {
  echo -e "${BLUE}Testing rate limits with curl...${NC}"
  echo -e "${BLUE}Running 10 consecutive requests to test rate limiting...${NC}"
  for i in {1..10}; do
    echo -e "${YELLOW}Request $i:${NC}"
    curl -s -I -H "Authorization: AWS4-HMAC-SHA256 Credential=5HQZO7EDOM4XBNO642GQ/20250904/us-east-1/s3/aws4_request" http://localhost/test | grep -E "X-RateLimit|X-Auth"
    echo ""
    sleep 0.5
  done
}

# Function to backup configuration files
function backup_configs() {
  BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"
  echo -e "${BLUE}Backing up configuration files to $BACKUP_DIR...${NC}"
  mkdir -p $BACKUP_DIR
  cp ./haproxy.cfg $BACKUP_DIR/
  cp ./extract_api_keys.lua $BACKUP_DIR/
  cp ./dynamic_rate_limiter.lua $BACKUP_DIR/
  cp -r ./config $BACKUP_DIR/
  echo -e "${GREEN}Backup created in $BACKUP_DIR/${NC}"
}

# Function to increase premium rate limits
function increase_limits() {
  LIMIT_AMOUNT=${1:-10000}
  BURST_AMOUNT=${2:-200}
  
  echo -e "${BLUE}Increasing premium rate limits...${NC}"
  echo -e "${YELLOW}Setting per-minute limit to: $LIMIT_AMOUNT${NC}"
  echo -e "${YELLOW}Setting per-second limit to: $BURST_AMOUNT${NC}"
  
  sed -i '' "s/premium [0-9]*/premium $LIMIT_AMOUNT/" ./config/rate_limits_per_minute.map
  sed -i '' "s/premium [0-9]*/premium $BURST_AMOUNT/" ./config/rate_limits_per_second.map
  
  echo -e "${GREEN}Rate limits increased. Remember to reload HAProxy with './manage.sh reload'${NC}"
}

# Main script logic
case "$1" in
  up)
    start_services
    ;;
  down)
    stop_services
    ;;
  restart)
    restart_services
    ;;
  reload|reload-haproxy)
    reload_haproxy
    ;;
  logs)
    view_logs
    ;;
  status)
    check_status
    ;;
  clean)
    clean_up
    ;;
  haproxy-stats)
    open_haproxy_stats
    ;;
  test-limits)
    test_rate_limits
    ;;
  backup-configs)
    backup_configs
    ;;
  increase-limits)
    increase_limits "$2" "$3"
    ;;
  help|--help|-h|*)
    show_help
    ;;
esac
