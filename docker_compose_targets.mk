# Determine the Docker Compose command to use
DOCKER_COMPOSE_CMD := $(shell if docker compose version > /dev/null 2>&1; then echo "docker compose"; elif docker-compose --version > /dev/null 2>&1; then echo "docker-compose"; else echo "docker-compose"; fi)

# Helper to print the selected Docker Compose command
docker-compose-info:
	@echo "Using Docker Compose command: $(DOCKER_COMPOSE_CMD)"
	@echo "Required Docker Compose version: $(DOCKER_COMPOSE_VERSION)"
	@$(DOCKER_COMPOSE_CMD) version || true
	@echo "Exporting project versions as environment variables..."
	@export MINIO_VERSION=$(MINIO_VERSION)
	@export HAPROXY_VERSION=$(HAPROXY_VERSION)

# Wrapper targets for Docker Compose commands
up: docker-compose-info
	@echo "Checking SSL directory structure..."
	@if [ ! -d "$(PROJECT_DIR)/haproxy/ssl" ]; then \
		echo "SSL directory not found, creating it..."; \
		mkdir -p $(PROJECT_DIR)/haproxy/ssl/certs; \
		mkdir -p $(PROJECT_DIR)/haproxy/ssl/private; \
		echo "SSL directory structure created."; \
	else \
		echo "SSL directory exists, continuing..."; \
	fi
	@if [ ! -f "$(PROJECT_DIR)/haproxy/ssl/certs/haproxy.pem" ]; then \
		echo "SSL certificates missing, generating self-signed certificates..."; \
		$(PROJECT_DIR)/scripts/generate-ssl-haproxy-certificates.sh; \
		echo "Self-signed certificates generated successfully."; \
	fi
	@echo "Starting all services..."
	@$(DOCKER_COMPOSE_CMD) up -d
	@echo "Services started. HAProxy endpoints:"
	@echo "  - Main: http://localhost:80"
	@echo "  - Stats: http://localhost:8404/stats"
	@echo "  - MinIO Console: http://localhost:9091"

down: docker-compose-info
	@echo "Stopping all services..."
	@$(DOCKER_COMPOSE_CMD) down
	@echo "Services stopped"

restart: docker-compose-info
	@echo "Restarting all services..."
	@$(DOCKER_COMPOSE_CMD) restart
	@echo "Services restarted"

logs: docker-compose-info
	@$(DOCKER_COMPOSE_CMD) logs -f

status: docker-compose-info
	@$(DOCKER_COMPOSE_CMD) ps

clean: docker-compose-info
	@echo "Cleaning up Docker resources..."
	@$(DOCKER_COMPOSE_CMD) down -v --remove-orphans
	@echo "Resources cleaned"
