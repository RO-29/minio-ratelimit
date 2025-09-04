# Makefile for MinIO Rate Limiting Comprehensive Test Suite
# =======================================================

# Variables
BINARY_NAME=minio-ratelimit-test
GO_FILES=$(shell find . -name "*.go" -type f)
BUILD_DIR=build
COVERAGE_DIR=coverage

# Default target
.PHONY: all
all: clean fmt vet test build

# Build the application
.PHONY: build
build: $(BUILD_DIR)/$(BINARY_NAME)

$(BUILD_DIR)/$(BINARY_NAME): $(GO_FILES)
	@echo "🏗️  Building $(BINARY_NAME)..."
	@mkdir -p $(BUILD_DIR)
	go build -o $(BUILD_DIR)/$(BINARY_NAME) .
	@echo "✅ Build complete: $(BUILD_DIR)/$(BINARY_NAME)"

# Run tests
.PHONY: test
test:
	@echo "🧪 Running unit tests..."
	go test -v -race ./...
	@echo "✅ All tests passed!"

# Run tests with coverage
.PHONY: test-coverage
test-coverage:
	@echo "🧪 Running tests with coverage..."
	@mkdir -p $(COVERAGE_DIR)
	go test -race -coverprofile=$(COVERAGE_DIR)/coverage.out -covermode=atomic ./...
	go tool cover -html=$(COVERAGE_DIR)/coverage.out -o $(COVERAGE_DIR)/coverage.html
	@echo "📊 Coverage report generated: $(COVERAGE_DIR)/coverage.html"

# Run benchmarks
.PHONY: bench
bench:
	@echo "🏃 Running benchmarks..."
	go test -bench=. -benchmem ./...

# Clean build artifacts
.PHONY: clean
clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	rm -rf $(COVERAGE_DIR)
	go clean -cache -testcache
	@echo "✅ Clean complete!"

# Run the application with default parameters (2 minutes)
.PHONY: run
run: build
	@echo "🚀 Running with default parameters (2 minutes)..."
	./$(BUILD_DIR)/$(BINARY_NAME) -duration=2m -accounts=3

# Run quick 30-second test
.PHONY: run-quick
run-quick: build
	@echo "⚡ Running quick test (30 seconds)..."
	./$(BUILD_DIR)/$(BINARY_NAME) -duration=30s -accounts=2

# Run premium stress test
.PHONY: run-premium
run-premium: build
	@echo "💪 Running premium stress test (5 minutes)..."
	./$(BUILD_DIR)/$(BINARY_NAME) -stress-premium -duration=5m -accounts=5

# Run with JSON export
.PHONY: run-json
run-json: build
	@echo "📊 Running with JSON export..."
	./$(BUILD_DIR)/$(BINARY_NAME) -duration=1m -json -output=test-results-$(shell date +%Y%m%d-%H%M%S).json

# Run specific tier tests
.PHONY: run-basic
run-basic: build
	@echo "🔰 Running basic tier only..."
	./$(BUILD_DIR)/$(BINARY_NAME) -tiers=basic -duration=1m

.PHONY: run-standard
run-standard: build
	@echo "📈 Running standard tier only..."
	./$(BUILD_DIR)/$(BINARY_NAME) -tiers=standard -duration=1m

.PHONY: run-premium-only
run-premium-only: build
	@echo "💎 Running premium tier only..."
	./$(BUILD_DIR)/$(BINARY_NAME) -tiers=premium -duration=1m

# Development targets
.PHONY: fmt
fmt:
	@echo "🎨 Formatting code..."
	go fmt ./...
	@echo "✅ Code formatted!"

.PHONY: vet
vet:
	@echo "🔍 Running go vet..."
	go vet ./...
	@echo "✅ Vet passed!"

# Lint with golint if available
.PHONY: lint
lint:
	@echo "🔍 Running linter..."
	@if command -v golint >/dev/null 2>&1; then \
		golint ./...; \
		echo "✅ Lint complete!"; \
	else \
		echo "⚠️  golint not installed. Install with: go install golang.org/x/lint/golint@latest"; \
	fi

# Static analysis with golangci-lint if available
.PHONY: lint-advanced
lint-advanced:
	@echo "🔍 Running advanced linter..."
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run ./...; \
		echo "✅ Advanced lint complete!"; \
	else \
		echo "⚠️  golangci-lint not installed. Install with: curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $$(go env GOPATH)/bin v1.54.2"; \
	fi

# Security check with gosec if available
.PHONY: security
security:
	@echo "🔒 Running security check..."
	@if command -v gosec >/dev/null 2>&1; then \
		gosec ./...; \
		echo "✅ Security check complete!"; \
	else \
		echo "⚠️  gosec not installed. Install with: go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest"; \
	fi

# Install development dependencies
.PHONY: install-dev-deps
install-dev-deps:
	@echo "📦 Installing development dependencies..."
	go install golang.org/x/lint/golint@latest
	go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest
	@echo "✅ Development dependencies installed!"

# Generate mocks (if needed in the future)
.PHONY: generate
generate:
	@echo "🔄 Running go generate..."
	go generate ./...
	@echo "✅ Generate complete!"

# Full CI pipeline
.PHONY: ci
ci: clean fmt vet lint test test-coverage bench build
	@echo "🎉 CI pipeline complete!"

# Check for module updates
.PHONY: deps-check
deps-check:
	@echo "🔍 Checking for dependency updates..."
	go list -u -m all
	@echo "✅ Dependency check complete!"

# Update dependencies
.PHONY: deps-update
deps-update:
	@echo "⬆️  Updating dependencies..."
	go get -u ./...
	go mod tidy
	@echo "✅ Dependencies updated!"

# Performance profiling
.PHONY: profile-cpu
profile-cpu: build
	@echo "📊 Running CPU profiling..."
	./$(BUILD_DIR)/$(BINARY_NAME) -duration=30s -accounts=1 -cpuprofile=cpu.prof
	go tool pprof cpu.prof

.PHONY: profile-mem
profile-mem: build
	@echo "📊 Running memory profiling..."
	./$(BUILD_DIR)/$(BINARY_NAME) -duration=30s -accounts=1 -memprofile=mem.prof
	go tool pprof mem.prof

# Docker support
.PHONY: docker-build
docker-build:
	@echo "🐳 Building Docker image..."
	docker build -t $(BINARY_NAME):latest .

.PHONY: docker-run
docker-run:
	@echo "🐳 Running in Docker..."
	docker run --rm -it $(BINARY_NAME):latest -duration=30s -accounts=1

# Help target - shows available commands
.PHONY: help
help:
	@echo ""
	@echo "📚 MinIO Rate Limiting Test Suite - Available Commands"
	@echo "======================================================"
	@echo ""
	@echo "🏗️  Build Targets:"
	@echo "  build              Build the application binary"
	@echo "  clean              Remove build artifacts and clean caches"
	@echo ""
	@echo "🧪 Testing Targets:"
	@echo "  test               Run unit tests with race detection"
	@echo "  test-coverage      Run tests with coverage report"
	@echo "  bench              Run benchmark tests"
	@echo ""
	@echo "🚀 Run Targets:"
	@echo "  run                Run with default parameters (2 minutes)"
	@echo "  run-quick          Quick 30-second test"
	@echo "  run-premium        Premium stress test (5 minutes)"
	@echo "  run-json           Run with JSON export"
	@echo "  run-basic          Test basic tier only"
	@echo "  run-standard       Test standard tier only"
	@echo "  run-premium-only   Test premium tier only"
	@echo ""
	@echo "🔍 Code Quality Targets:"
	@echo "  fmt                Format code with go fmt"
	@echo "  vet                Run go vet static analysis"
	@echo "  lint               Run golint (if installed)"
	@echo "  lint-advanced      Run golangci-lint (if installed)"
	@echo "  security           Run security check with gosec (if installed)"
	@echo ""
	@echo "📦 Dependency Targets:"
	@echo "  deps-check         Check for dependency updates"
	@echo "  deps-update        Update dependencies"
	@echo "  install-dev-deps   Install development dependencies"
	@echo ""
	@echo "📊 Advanced Targets:"
	@echo "  profile-cpu        Run with CPU profiling"
	@echo "  profile-mem        Run with memory profiling"
	@echo "  generate           Run go generate"
	@echo "  ci                 Full CI pipeline (fmt, vet, lint, test, build)"
	@echo ""
	@echo "🐳 Docker Targets:"
	@echo "  docker-build       Build Docker image"
	@echo "  docker-run         Run in Docker container"
	@echo ""
	@echo "Examples:"
	@echo "  make run-quick                    # Quick 30-second test"
	@echo "  make run-premium                  # Stress test premium accounts"
	@echo "  make test-coverage               # Run tests with coverage"
	@echo "  make run-json                    # Export results to timestamped JSON"
	@echo "  make ci                          # Full CI pipeline"
	@echo ""
	@echo "For more options, run the binary directly:"
	@echo "  ./build/$(BINARY_NAME) --help"
	@echo ""

# Default help when no target specified
.DEFAULT_GOAL := help