# MinIO Rate Limiting Comprehensive Test Suite

A sophisticated testing tool designed to validate and benchmark MinIO's rate limiting capabilities across different service tiers. This tool performs comprehensive testing using multiple clients (MinIO Go SDK, AWS S3 SDK, and direct HTTP API) to ensure rate limits are applied correctly and consistently.

## 🚀 Features

- **Multi-client Testing**: Tests rate limits with MinIO Go SDK, AWS S3 SDK, and direct HTTP API
- **Tier-based Testing**: Tests different service tiers (basic, standard, premium)
- **Real-time Monitoring**: Displays progress and statistics during test execution
- **Comprehensive Reporting**: Generates detailed reports with rate limiting insights
- **Burst Testing**: Special mode to test burst rate limits and throttling behavior
- **Stress Testing**: Premium tier stress testing to find actual limits under heavy load
- **Header Analysis**: Captures and analyzes rate limit headers for deep insights
- **JSON Export**: Option to export detailed results for further analysis
- **Docker Support**: Run in Docker for consistent testing environment

## 📁 File Structure

| File | Purpose |
|------|---------|
| `main.go` | Main entry point and test execution flow |
| `config.go` | Command-line flag parsing and configuration loading |
| `types.go` | All type definitions and data structures |
| `accounts.go` | Account selection and grouping logic |
| `tests.go` | All test execution functions (MinIO, AWS S3, HTTP API, etc.) |
| `progress.go` | Real-time progress tracking and display |
| `reporting.go` | Report generation and comprehensive analysis |
| `export.go` | JSON export functionality |
| `utils.go` | Helper functions and error categorization |
| `Dockerfile` | Docker configuration for containerized testing |
| `Makefile` | Build and test automation |

## 🔧 Prerequisites

- Go 1.21 or higher
- Docker (for containerized testing)
- Service account configuration in JSON format

## 📋 Installation

### Local Installation

```bash
# Clone the repository
git clone https://github.com/your-org/minio-ratelimit.git
cd minio-ratelimit/cmd/ratelimit-test

# Set up the environment
make setup

# Build the binary
make build
```

### Docker Installation

```bash
# Clone the repository
git clone https://github.com/your-org/minio-ratelimit.git
cd minio-ratelimit/cmd/ratelimit-test

# Build Docker image
make docker-build
```

## 🧪 Usage

### Command-line Options

```bash
Usage: ./build/minio-ratelimit-test [options]

Options:
  -accounts int      Number of accounts per tier to test (default 3)
  -config string     Path to service accounts config file
  -duration duration Test duration (e.g., 60s, 2m, 5m) (default 2m0s)
  -json              Export detailed results to JSON file
  -output string     Output file for JSON export (default "rate_limit_test_results.json")
  -stress-premium    Stress test premium accounts to find actual limits
  -tiers string      Comma-separated list of tiers to test (default "basic,standard,premium")
  -verbose           Enable verbose logging
```

### Using the Makefile

```bash
# Quick test
./build/ratelimit-test -duration=30s -accounts=2

# Stress test premium accounts
./build/ratelimit-test -stress-premium -duration=5m

# Export detailed results to JSON
./build/ratelimit-test -json -output=results.json

# Test specific tiers with custom settings
./build/ratelimit-test -tiers=premium -accounts=5 -duration=10m
```

## Module Dependencies

```bash
# Local mode: Run standard test
make test

# Local mode: Run quick test (10 seconds)
make quick-test

# Local mode: Run premium stress test
make stress-test

# Local mode: Run test with JSON export
make json-export

# Local mode: Run unit tests only
make unit-test

# Local mode: Generate coverage report
make coverage

# Docker mode: Build Docker image
make docker-build

# Docker mode: Run test in Docker
make docker-run

# Docker mode: One-step build and run
make docker-test
```

## 📈 Example Workflow

### 1. Local Development Testing

```bash
# Setup environment and build the binary
make setup build

# Run a quick test to verify everything is working
make quick-test

# Run a comprehensive test with standard parameters
make test

# Generate test coverage report
make coverage
```

### 2. Docker-based Testing

```bash
# Build Docker image and run test
make docker-test

# Analyze results
cat docker-results/docker_results.json
```

### 3. Premium Tier Stress Testing

```bash
# Run stress test focusing on premium tier
make stress-test

# Examine the results
cat stress_test_results.json
```

## 📊 Understanding Results

The test produces a comprehensive report with:

1. **Overall Success Rate**: Percentage of successful requests
2. **Rate Limiting Analysis**: Details of throttled requests by tier
3. **Burst Patterns**: Analysis of burst request handling
4. **Header Analysis**: Rate limit header information
5. **Error Breakdown**: Categorized error information

## 🐳 Docker Support

The included Dockerfile provides a containerized environment for running tests:

```dockerfile
FROM golang:1.21-alpine
WORKDIR /app
COPY . .
RUN go mod download
RUN go build -o minio-ratelimit-test .
ENTRYPOINT ["./minio-ratelimit-test"]
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -am 'Add my feature'`
4. Push the branch: `git push origin feature/my-feature`
5. Submit a pull request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.
