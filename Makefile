# MinIO Rate Limiting with HAProxy - Management Makefile
#
# Common commands:
#   make up          - Start all services
#   make down        - Stop all services
#   make restart     - Restart all services
#   make reload      - Reload HAProxy without downtime
#   make logs        - View logs from all services
#   make status      - Check service status
#   make clean       - Clean up Docker resources
#
# HAProxy specific:
#   make reload-haproxy   - Reload only HAProxy configs
#   make haproxy-stats    - Open HAProxy stats in browser
#   make test-limits      - Run a simple rate limit test
#
# Configuration management:
#   make backup-configs   - Backup all configuration files
#   make increase-limits  - Increase premium rate limits

.PHONY: up down restart reload logs status clean reload-haproxy haproxy-stats test-limits backup-configs increase-limits update-maps help

# Default target
help:
	@echo "MinIO Rate Limiting with HAProxy - Management Commands"
	@echo ""
	@echo "Usage:"
	@echo "  make up                - Start all services"
	@echo "  make down              - Stop all services"
	@echo "  make restart           - Restart all services"
	@echo "  make reload            - Reload HAProxy without downtime"
	@echo "  make logs              - View logs from all services"
	@echo "  make status            - Check service status"
	@echo "  make clean             - Clean up Docker resources"
	@echo ""
	@echo "HAProxy specific:"
	@echo "  make reload-haproxy    - Reload only HAProxy configs"
	@echo "  make haproxy-stats     - Open HAProxy stats in browser"
	@echo "  make test-limits       - Run a simple rate limit test"
	@echo ""
	@echo "Configuration management:"
	@echo "  make backup-configs    - Backup all configuration files"
	@echo "  make increase-limits   - Increase premium rate limits"
	@echo "  make update-maps       - Update HAProxy map files only"

# Start all services
up:
	@echo "Starting all services..."
	@docker-compose up -d
	@echo "Services started. HAProxy endpoints:"
	@echo "  - Main: http://localhost:80"
	@echo "  - Stats: http://localhost:8404/stats"
	@echo "  - MinIO Console: http://localhost:9091"

# Stop all services
down:
	@echo "Stopping all services..."
	@docker-compose down
	@echo "Services stopped"

# Restart all services
restart:
	@echo "Restarting all services..."
	@docker-compose restart
	@echo "Services restarted"

# Reload HAProxy without stopping containers
reload: reload-haproxy

# View logs
logs:
	@docker-compose logs -f

# Check status
status:
	@docker-compose ps

# Clean up
clean:
	@echo "Cleaning up Docker resources..."
	@docker-compose down -v --remove-orphans
	@echo "Resources cleaned"

# Reload HAProxy configuration
reload-haproxy:
	@echo "Reloading HAProxy configuration without downtime..."
	@echo "Reloading HAProxy 1..."
	@docker-compose exec haproxy1 kill -SIGUSR2 1
	@sleep 2
	@echo "Reloading HAProxy 2..."
	@docker-compose exec haproxy2 kill -SIGUSR2 1
	@echo "HAProxy configuration reloaded"

# Open HAProxy stats in browser
haproxy-stats:
	@echo "Opening HAProxy stats in browser..."
	@open http://localhost:8404/stats

# Test rate limits with curl
test-limits:
	@echo "Testing rate limits with curl..."
	@echo "Running 5 consecutive requests to test rate limiting..."
	@curl -v -H "Authorization: AWS4-HMAC-SHA256 Credential=5HQZO7EDOM4XBNO642GQ/20250904/us-east-1/s3/aws4_request" http://localhost/
	@echo "\n\nChecking response with verbose output to see all headers..."
	@curl -v -H "Authorization: AWS4-HMAC-SHA256 Credential=5HQZO7EDOM4XBNO642GQ/20250904/us-east-1/s3/aws4_request" http://localhost/

# Backup all configuration files
backup-configs:
	@echo "Backing up configuration files..."
	@mkdir -p ./backups/$(shell date +%Y%m%d_%H%M%S)
	@cp ./haproxy.cfg ./backups/$(shell date +%Y%m%d_%H%M%S)/
	@cp ./extract_api_keys.lua ./backups/$(shell date +%Y%m%d_%H%M%S)/
	@cp ./dynamic_rate_limiter.lua ./backups/$(shell date +%Y%m%d_%H%M%S)/
	@cp -r ./config ./backups/$(shell date +%Y%m%d_%H%M%S)/
	@echo "Backup created in ./backups/$(shell date +%Y%m%d_%H%M%S)/"

# Increase premium rate limits
increase-limits:
	@echo "Increasing premium rate limits..."
	@sed -i '' 's/premium [0-9]*/premium 10000/' ./config/rate_limits_per_minute.map
	@sed -i '' 's/premium [0-9]*/premium 200/' ./config/rate_limits_per_second.map
	@echo "Rate limits increased. Remember to reload HAProxy with 'make reload'"

# Update HAProxy map files
update-maps:
	@echo "Updating HAProxy map files..."
	@for container in haproxy1 haproxy2; do \
		docker-compose exec $$container sh -c "cat /usr/local/etc/haproxy/config/rate_limits_per_minute.map | sed 's/\r//' > /tmp/rate_limits_per_minute.map && mv /tmp/rate_limits_per_minute.map /usr/local/etc/haproxy/config/rate_limits_per_minute.map"; \
		docker-compose exec $$container sh -c "cat /usr/local/etc/haproxy/config/rate_limits_per_second.map | sed 's/\r//' > /tmp/rate_limits_per_second.map && mv /tmp/rate_limits_per_second.map /usr/local/etc/haproxy/config/rate_limits_per_second.map"; \
		docker-compose exec $$container sh -c "cat /usr/local/etc/haproxy/config/api_key_groups.map | sed 's/\r//' > /tmp/api_key_groups.map && mv /tmp/api_key_groups.map /usr/local/etc/haproxy/config/api_key_groups.map"; \
	done
	@echo "Map files updated. Remember to reload HAProxy with 'make reload'"
