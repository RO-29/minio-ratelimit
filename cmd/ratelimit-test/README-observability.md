# MinIO Rate Limiting + ClickHouse Observability

## 🎯 Overview

This setup provides comprehensive analysis of your MinIO HTTP request logs using ClickHouse 25.8 for high-performance data storage and analysis.

**What it does:**
- Ingests MinIO rate limiting test results into ClickHouse
- Provides rich analysis tools for performance metrics
- Offers web-based query interface for custom analysis
- Includes pre-built analysis scripts for common use cases

## 🚀 Quick Start

### One Command Setup
```bash
make quick-start
```
This will:
- ✅ Start ClickHouse container
- ✅ Run MinIO rate limiting tests
- ✅ Import results into ClickHouse
- ✅ Show complete analysis
- ✅ Open web interface

### Manual Step-by-Step
```bash
# 1. Setup ClickHouse
make setup

# 2. Run tests and import data
make test-and-import

# 3. Analyze results
make analyze-all

# 4. Open web interface
make dashboard
```

## 📊 Available Commands

### Setup & Management
```bash
make setup          # Start ClickHouse container
make status          # Check service status
make logs            # Show ClickHouse logs
make restart         # Restart services
make clean          # Stop and remove everything
```

### Testing & Data Import
```bash
make test            # Run MinIO rate limiting test
make import          # Import results to ClickHouse
make test-and-import # Run test + import in one command
```

### Analysis Commands
```bash
make analyze                # System overview
make analyze-groups         # Performance by group
make analyze-latency        # Latency analysis  
make analyze-rate-limits    # Rate limiting effectiveness
make analyze-summary        # Executive summary
make analyze-all           # Complete analysis report
```

### Custom Queries
```bash
make query SQL="SELECT * FROM minio_logs.test_results"
make query SQL="SELECT group, avg(avg_latency_ms) FROM minio_logs.test_results GROUP BY group"
```

### Web Interface
```bash
make dashboard      # Opens ClickHouse web UI at http://localhost:8123/play
```

## 🔍 Analysis Tools

### Built-in Analysis Script
```bash
./analyze.sh help              # Show all available commands
./analyze.sh overview          # System overview
./analyze.sh groups           # Performance by group
./analyze.sh latency          # Latency analysis
./analyze.sh rate-limits      # Rate limiting effectiveness
./analyze.sh summary          # Executive summary
./analyze.sh raw              # Show raw data
```

### Direct ClickHouse Access
```bash
# Via curl
curl "http://localhost:8123/" -d "SELECT * FROM minio_logs.test_results"

# Via web interface
# Open http://localhost:8123/play in browser
```

## 📈 Example Analysis Results

### System Overview
```
┌─metric─────────────┬─value─┐
│ Total Requests     │ 1730  │
│ Total Success      │ 763   │
│ Success Rate %     │ 44.1  │
│ Rate Limited       │ 396   │
└────────────────────┴───────┘
```

### Performance by Group
```
┌─group────┬─requests_sent─┬─success_rate_pct─┬─rate_limit_pct─┬─avg_latency─┐
│ premium  │           675 │            55.56 │              0 │         670 │
│ standard │           675 │            55.41 │          17.93 │         721 │
│ basic    │           380 │             3.68 │          72.37 │        4501 │
└──────────┴───────────────┴──────────────────┴────────────────┴─────────────┘
```

## 🗂️ Data Schema

The `minio_logs.test_results` table contains:
```sql
- timestamp         DateTime64(3)     -- When the test was run
- test_id           String            -- Unique test identifier
- group             LowCardinality    -- Rate limit group (premium/standard/basic)
- api_key           String            -- API key used in test
- method            LowCardinality    -- Test method
- requests_sent     UInt32            -- Total requests sent
- success_count     UInt32            -- Successful requests
- rate_limited_count UInt32           -- Rate limited requests
- error_count       UInt32            -- Failed requests
- avg_latency_ms    Float64           -- Average latency in milliseconds
- auth_method       LowCardinality    -- Authentication method used
```

## 🔧 Configuration

### ClickHouse Settings
- **Image**: `clickhouse/clickhouse-server:latest`
- **HTTP Port**: 8123
- **Native Port**: 9000
- **Database**: `minio_logs`
- **Table**: `test_results`

### Data Retention
- Default: No automatic cleanup
- Manual cleanup: `make clean` removes all data
- Custom retention can be added to the schema

## 💡 Use Cases

### 1. Performance Monitoring
```bash
make analyze-latency    # Check latency by group
./analyze.sh latency    # Detailed latency analysis
```

### 2. Rate Limiting Effectiveness
```bash
make analyze-rate-limits    # See which groups hit limits
./analyze.sh rate-limits    # Detailed rate limiting analysis
```

### 3. Capacity Planning
```bash
make query SQL="SELECT group, max(requests_sent) as peak_load FROM minio_logs.test_results GROUP BY group"
```

### 4. Custom Reporting
```bash
# Success rate trends
make query SQL="SELECT group, round(avg(success_count/requests_sent*100), 2) as avg_success_rate FROM minio_logs.test_results GROUP BY group ORDER BY avg_success_rate DESC"

# Latency percentiles (requires multiple test runs)
make query SQL="SELECT group, quantile(0.5)(avg_latency_ms) as p50, quantile(0.95)(avg_latency_ms) as p95 FROM minio_logs.test_results GROUP BY group"
```

## 🚨 Troubleshooting

### ClickHouse Not Starting
```bash
make logs           # Check logs
make restart        # Restart services
docker ps -a        # Check container status
```

### No Data After Import
```bash
make status         # Verify ClickHouse is running
make query SQL="SELECT count() FROM minio_logs.test_results"   # Check record count
python3 import_data.py  # Re-run import
```

### Custom Query Errors
```bash
# Test basic connectivity
curl http://localhost:8123/ping

# Check table exists
make query SQL="SHOW TABLES FROM minio_logs"

# Check table schema
make query SQL="DESCRIBE minio_logs.test_results"
```

## 📁 Files Structure

```
cmd/ratelimit-test/
├── Makefile                     # Main automation commands
├── docker-compose.observability.yml  # ClickHouse container
├── analyze.sh                   # Analysis script
├── import_data.py               # Data import script
├── comprehensive_results.json   # Test results (generated)
└── README-OBSERVABILITY.md      # This file
```

## 🎉 Success Metrics

After setup, you should see:
- ✅ ClickHouse running on port 8123
- ✅ Data imported successfully
- ✅ Analysis commands returning results
- ✅ Web interface accessible
- ✅ Custom queries working

## 🔗 Access Points

- **ClickHouse HTTP**: http://localhost:8123
- **ClickHouse Web UI**: http://localhost:8123/play
- **Health Check**: http://localhost:8123/ping

---

This setup provides production-ready observability for MinIO rate limiting with minimal complexity and maximum insight capability!