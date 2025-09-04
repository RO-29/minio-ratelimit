# Complete MinIO Rate Limiting + Observability Workflow

## 🎯 How the Complete Integration Works

This guide explains the end-to-end workflow of testing MinIO rate limiting and visualizing the results using modern observability tools.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           COMPLETE INTEGRATION FLOW                          │
└─────────────────────────────────────────────────────────────────────────────┘

1. SETUP PHASE
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────┐
│   MinIO + HAProxy    │ ClickHouse 25.8    │    HyperDX + Vector    │
│                │    │                │    │                    │
│ • S3 API      │    │ • Log Storage   │    │ • Dashboards       │
│ • Rate Limits │    │ • Analytics     │    │ • Data Processing  │
│ • Auth Tests  │    │ • SQL Queries   │    │ • Visualization    │
└─────────────────┘    └─────────────────┘    └─────────────────────┘

2. TESTING PHASE
┌─────────────────────────────────────────────────────────────────────────────┐
│                          GO TEST EXECUTION                                  │
│                                                                             │
│  fast_parallel.go  ──→  HTTP Requests  ──→  comprehensive_results.json     │
│                                                                             │
│  • 27 concurrent scenarios                                                 │
│  • Multiple auth methods (V2, V4, presigned URLs)                          │
│  • Different rate limit tiers (premium, standard, basic)                   │
│  • Real MinIO service accounts                                             │
└─────────────────────────────────────────────────────────────────────────────┘

3. INGESTION PHASE
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DATA PROCESSING PIPELINE                            │
│                                                                             │
│  comprehensive_results.json ──→ Vector ──→ ClickHouse ──→ HyperDX          │
│                                                                             │
│  • JSON parsing and flattening                                             │
│  • Schema transformation                                                    │
│  • Real-time data streaming                                                │
│  • Automated dashboard updates                                             │
└─────────────────────────────────────────────────────────────────────────────┘

4. VISUALIZATION PHASE
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ANALYSIS & INSIGHTS                               │
│                                                                             │
│  HyperDX Dashboards    ClickHouse Queries    Custom Analysis               │
│                                                                             │
│  • Rate limiting trends                                                     │
│  • Performance metrics                                                      │
│  • Error analysis                                                          │
│  • API key behavior                                                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start Workflows

### 1. Complete First-Time Setup
```bash
# One command to set up everything
make quick-start

# What this does:
# ✅ Checks Docker, Docker Compose, Go dependencies
# ✅ Starts MinIO and HAProxy services
# ✅ Sets up ClickHouse 25.8 + HyperDX + Vector
# ✅ Runs comprehensive rate limiting test
# ✅ Ingests data into ClickHouse
# ✅ Opens dashboard in browser
```

### 2. Development Workflow
```bash
# Run tests and analyze results
make test-full          # Run 60-second comprehensive test
make ingest-data        # Process results into ClickHouse
make query-overview     # Show summary statistics
make dashboard          # Open visualization dashboards
```

### 3. Continuous Monitoring
```bash
# Terminal 1: Continuous testing
make test-continuous

# Terminal 2: Live log monitoring
make logs-follow

# Terminal 3: Real-time analysis
make query-trends
make query-rate-limits
```

### 4. Performance Benchmarking
```bash
# Run benchmark suite
make benchmark          # Tests with 30s, 60s, 120s durations
make stress-test        # 5-minute continuous load test
make query-performance  # Analyze performance results
```

## 📊 Data Flow Explained

### Stage 1: Test Data Generation
```json
// comprehensive_results.json structure
{
  "summary": {
    "TotalTests": 36,
    "Duration": 60121364500,
    "ByGroup": {
      "premium": {
        "RequestsSent": 675,
        "Success": 375,
        "RateLimited": 0,
        "AvgLatencyMs": 670,
        "AuthMethod": "v4_header_lua"
      },
      "standard": {...},
      "basic": {...}
    }
  }
}
```

### Stage 2: Vector Processing
```toml
# vector/vector.toml - Key transformations
[transforms.parse_json_results]
source = '''
  .parsed = parse_json!(string!(.message))
  .event_type = "summary"
  .groups = .parsed.summary.ByGroup
'''

[transforms.flatten_groups]
source = '''
  # Creates individual records for each group
  # Flattens nested JSON structure
  # Adds timestamps and IDs
'''
```

### Stage 3: ClickHouse Storage
```sql
-- Optimized schema for analysis
CREATE TABLE test_results (
    timestamp DateTime64(3),
    group LowCardinality(String),
    requests_sent UInt32,
    success_count UInt32,
    rate_limited_count UInt32,
    avg_latency_ms Float64,
    -- ... additional metrics
) ENGINE = MergeTree()
ORDER BY (timestamp, group, api_key)
```

### Stage 4: Real-time Analysis
```sql
-- Pre-built views for instant insights
SELECT * FROM rate_limit_analysis;      -- Rate limiting patterns
SELECT * FROM performance_by_group;     -- Performance metrics  
SELECT * FROM hourly_metrics;           -- Time-series trends
```

## 🔧 Available Make Commands

### Essential Commands
| Command | Purpose | Description |
|---------|---------|-------------|
| `make quick-start` | Complete setup | Install deps + setup all + test + observe |
| `make status` | System health | Check all service status |
| `make dashboard` | Open UI | Launch dashboards in browser |
| `make logs` | Debug | Show logs from all services |

### Testing Commands
| Command | Purpose | Use Case |
|---------|---------|----------|
| `make test-quick` | 30-second test | Quick validation |
| `make test-full` | 60-second test | Standard comprehensive test |
| `make test-continuous` | Ongoing testing | Load testing / monitoring |
| `make benchmark` | Performance suite | Compare different configurations |
| `make stress-test` | 5-minute load | Stress testing |

### Data Analysis Commands
| Command | Output | Use For |
|---------|---------|---------|
| `make query-health` | System status | Health checks |
| `make query-overview` | Summary stats | Quick overview |
| `make query-performance` | Latency metrics | Performance analysis |
| `make query-rate-limits` | Rate limiting data | Rate limit effectiveness |
| `make query-errors` | Error breakdown | Troubleshooting |
| `make query-trends` | Time series data | Trend analysis |

### Custom Analysis
```bash
# Custom SQL queries
make query-custom SQL="SELECT group, avg(avg_latency_ms) FROM minio_logs.test_results GROUP BY group"

# Interactive shell
make dev-shell
# Then run any ClickHouse SQL queries

# Data export
make export-data                # Export to JSON
make backup-data               # Create backup
```

## 🎯 Real-World Usage Scenarios

### Scenario 1: API Performance Validation
```bash
# 1. Set up environment
make setup-all

# 2. Run performance test
make test-full

# 3. Analyze results
make query-performance
make query-trends

# 4. Generate report
make export-data
```

### Scenario 2: Rate Limiting Tuning
```bash
# 1. Baseline measurement
make test-full
make query-rate-limits

# 2. Modify rate limits (via your rate limit config)
# 3. Test again
make test-full

# 4. Compare results
make query-custom SQL="SELECT group, rate_limit_percentage, timestamp FROM minio_logs.rate_limit_analysis ORDER BY timestamp DESC"
```

### Scenario 3: Capacity Planning
```bash
# 1. Run stress test
make stress-test

# 2. Analyze capacity metrics
make query-custom SQL="
SELECT 
  group,
  max(current_per_minute) as peak_usage,
  avg(limit_per_minute) as configured_limit,
  round(max(current_per_minute) / avg(limit_per_minute) * 100, 2) as utilization_pct
FROM minio_logs.test_results 
WHERE limit_per_minute > 0 
GROUP BY group
"

# 3. Generate capacity report
make export-data
```

### Scenario 4: Troubleshooting Issues
```bash
# 1. Check system health
make status
make query-health

# 2. Analyze errors
make query-errors
make logs

# 3. Deep dive with custom queries
make dev-shell
# Run diagnostic SQL queries
```

## 📈 Dashboard Features

### HyperDX Dashboards (http://localhost:8080)
1. **Rate Limiting Overview**
   - Request success rates by group
   - Rate limiting effectiveness
   - API key performance comparison

2. **Performance Analytics**
   - Latency percentiles (P50, P95, P99)
   - Performance trends over time
   - Group-based performance comparison

3. **Error Analysis**
   - Error breakdown by type
   - High error rate API keys
   - Error patterns over time

4. **Real-time Monitoring**
   - Live request counts
   - Active API keys
   - System health metrics

### ClickHouse Query Interface (http://localhost:8123/play)
- Direct SQL access to all data
- Custom query building
- Data export capabilities
- Performance query optimization

## 🔄 Integration Points

### With Your Existing System
```bash
# 1. Existing MinIO setup
cd ../../ && docker-compose up -d    # Your main services

# 2. Add observability layer
cd cmd/comprehensive-test
make setup-observability            # Add monitoring stack

# 3. Run analysis
make test-and-observe               # Test + analyze
```

### With CI/CD Pipelines
```yaml
# .github/workflows/performance-test.yml
- name: Run Performance Test
  run: |
    cd cmd/comprehensive-test
    make quick-start
    make query-overview > performance-report.txt
    make export-data
```

### With External Monitoring
```bash
# Export metrics for external systems
make export-data                    # JSON format
make backup-data                   # Full backup

# API access to ClickHouse
curl "http://localhost:8123/?query=SELECT * FROM minio_logs.rate_limit_analysis FORMAT JSON"
```

## 🛠️ Customization Options

### Test Duration
```bash
make test-custom DURATION=300      # 5-minute test
make test-custom DURATION=1800     # 30-minute test
```

### Custom Queries
```bash
# Add your own queries to query-examples.sql
make query-custom SQL="YOUR_CUSTOM_QUERY"
```

### Dashboard Modifications
```bash
# Edit hyperdx/config.json for custom dashboards
# Restart to apply changes
make observe-restart
```

### Data Retention
```bash
# Modify TTL in clickhouse/init.sql
# Default: 90 days for test_results, 30 days for http_requests
make clean-data                    # Manual cleanup
```

## 🎉 Success Metrics

After running the complete integration, you should see:

✅ **Successful Setup**: All services running (ClickHouse, HyperDX, Vector)
✅ **Data Ingestion**: Records in ClickHouse (check with `make query-health`)
✅ **Visualization**: Working dashboards at http://localhost:8080
✅ **Analysis Ready**: Queries returning meaningful data
✅ **Performance Insights**: Clear latency and rate limiting patterns

## 🚨 Troubleshooting

### Common Issues
```bash
# Service not starting
make status                        # Check service status
make logs                         # Check error logs

# No data in ClickHouse
make ingest-data                  # Manually trigger ingestion
make logs-vector                  # Check Vector processing

# Dashboard not loading
make observe-restart              # Restart observability stack
curl http://localhost:8080/health # Check HyperDX health
```

### Performance Issues
```bash
# ClickHouse performance
make query-custom SQL="SHOW PROCESSLIST"  # Check running queries
make clean-data                            # Clean old data

# System resources
docker stats                               # Check container resources
make update-images                         # Update to latest versions
```

This complete integration gives you production-ready observability for MinIO rate limiting with minimal setup and maximum insight capability!