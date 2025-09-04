# MinIO Rate Limiting Observability Stack

## 🎯 Overview

This observability stack provides comprehensive visualization and analysis of your MinIO HTTP request logs using modern observability tools:

- **ClickHouse 25.8**: High-performance columnar database for log storage and analytics
- **HyperDX**: Modern observability platform for dashboards and alerting
- **Vector**: High-performance log processing and ingestion pipeline

## 🚀 Quick Start

1. **Setup the observability stack:**
   ```bash
   ./setup-observability.sh
   ```

2. **Access the dashboards:**
   - HyperDX Web UI: http://localhost:8080
   - ClickHouse HTTP: http://localhost:8123
   - Vector API: http://localhost:8686

3. **Run your MinIO tests to generate data:**
   ```bash
   go run fast_parallel.go  # This generates comprehensive_results.json
   ```

## 📊 Available Dashboards

### 1. Rate Limiting Overview
- Total requests and success rates
- Rate limiting statistics by group
- Request distribution visualizations

### 2. Performance Analytics  
- Latency trends by group and time
- Performance percentiles (P50, P95, P99)
- Latency vs success rate correlations

### 3. Rate Limiting Analysis
- Rate limiting patterns by authentication method
- API keys hitting limits most frequently
- Rate limiting efficiency by group

### 4. Error Analysis
- Error breakdown by type and group
- High error rate API keys
- Error patterns over time

## 🔍 Key Data Views

### Test Results Table Schema
```sql
CREATE TABLE test_results (
    timestamp DateTime64(3),
    test_id String,
    group LowCardinality(String),
    api_key String,
    method LowCardinality(String),
    requests_sent UInt32,
    success_count UInt32,
    rate_limited_count UInt32,
    error_count UInt32,
    avg_latency_ms Float64,
    auth_method LowCardinality(String),
    rate_limit_group LowCardinality(String),
    -- ... additional fields
) ENGINE = MergeTree()
ORDER BY (timestamp, group, api_key);
```

### Pre-built Views
- `rate_limit_analysis`: Rate limiting statistics per API key
- `performance_by_group`: Performance metrics aggregated by group
- `hourly_metrics`: Time-series data for trending analysis

## 🔧 Configuration Files

### Docker Compose
- `docker-compose.observability.yml`: Main service definitions
- Uses latest ClickHouse 25.8 with optimized JSON processing
- HyperDX configured for MinIO log analysis

### ClickHouse Configuration
- `clickhouse/config.xml`: Server configuration with JSON format optimization
- `clickhouse/users.xml`: User access and security settings
- `clickhouse/init.sql`: Database schema and views creation

### Vector Configuration  
- `vector/vector.toml`: Log processing pipeline
- Parses `comprehensive_results.json` structure
- Transforms nested JSON into flattened ClickHouse records

### HyperDX Configuration
- `hyperdx/config.json`: Dashboard and alert definitions
- Pre-configured queries for MinIO rate limiting analysis

## 📈 Example Queries

### Overall System Health
```sql
SELECT
    sum(requests_sent) as total_requests,
    sum(success_count) as total_success,
    round(sum(success_count) / sum(requests_sent) * 100, 2) as success_percentage,
    round(sum(rate_limited_count) / sum(requests_sent) * 100, 2) as rate_limit_percentage
FROM test_results;
```

### Performance by Group
```sql
SELECT * FROM performance_by_group;
```

### Rate Limiting Analysis
```sql
SELECT * FROM rate_limit_analysis 
WHERE total_requests > 10 
ORDER BY rate_limit_percentage DESC;
```

### Time-based Trends
```sql
SELECT * FROM hourly_metrics 
WHERE hour >= now() - INTERVAL 24 HOUR 
ORDER BY hour DESC;
```

See `query-examples.sql` for 20+ additional analysis queries.

## 🚨 Alerts and Monitoring

Pre-configured alerts in HyperDX:
- **High Rate Limiting**: Alert when rate limiting exceeds 50%
- **High Error Rate**: Alert when error rate exceeds 25%  
- **High Latency**: Alert when average latency exceeds 1000ms

## 📊 Data Flow

```
comprehensive_results.json
           ↓
    Vector (parsing)
           ↓
    ClickHouse (storage)
           ↓
     HyperDX (visualization)
```

1. **Data Generation**: Your MinIO tests generate `comprehensive_results.json`
2. **Ingestion**: Vector reads and parses the JSON file
3. **Transformation**: Vector flattens nested structures for ClickHouse
4. **Storage**: ClickHouse stores data in optimized columnar format
5. **Visualization**: HyperDX queries ClickHouse for dashboard updates

## 🛠️ Advanced Usage

### Custom Queries
Connect directly to ClickHouse for custom analysis:
```bash
# Interactive client
docker-compose -f docker-compose.observability.yml exec clickhouse clickhouse-client

# Web interface  
curl "http://localhost:8123/play"
```

### Real-time HAProxy Logs
The stack also ingests real-time HAProxy logs for live monitoring:
```yaml
# In vector/vector.toml
[sources.docker_logs]
type = "docker_logs"
include_containers = ["haproxy1", "haproxy2"]
```

### Data Retention
- Test results: 90 days (configurable via TTL)
- HTTP request logs: 30 days
- Automatic partitioning by month for optimal performance

## 🔧 Troubleshooting

### Check Service Health
```bash
# Service status
docker-compose -f docker-compose.observability.yml ps

# ClickHouse health
curl http://localhost:8123/ping

# HyperDX health  
curl http://localhost:8080/health

# Vector logs
docker-compose -f docker-compose.observability.yml logs vector
```

### Verify Data Ingestion
```bash
# Check record count
docker-compose -f docker-compose.observability.yml exec clickhouse clickhouse-client \
  --query "SELECT count() FROM minio_logs.test_results"

# View recent data
docker-compose -f docker-compose.observability.yml exec clickhouse clickhouse-client \
  --query "SELECT * FROM minio_logs.test_results ORDER BY timestamp DESC LIMIT 5" \
  --format PrettyCompact
```

### Performance Tuning
- **Memory**: ClickHouse uses ~80% of available RAM by default
- **Storage**: Data is compressed with LZ4 for optimal space usage
- **Queries**: Pre-built materialized views for faster dashboard queries

## 📁 File Structure

```
cmd/comprehensive-test/
├── docker-compose.observability.yml    # Main Docker Compose file
├── setup-observability.sh              # Automated setup script
├── query-examples.sql                   # 20+ example queries
├── README-observability.md             # This file
├── clickhouse/
│   ├── config.xml                      # ClickHouse server config
│   ├── users.xml                       # User management
│   └── init.sql                        # Schema and views
├── hyperdx/
│   └── config.json                     # Dashboard definitions
└── vector/
    └── vector.toml                     # Log processing pipeline
```

## 🎨 Visualization Examples

The HyperDX dashboards provide:

1. **Real-time Metrics**: Current request rates, success rates, error rates
2. **Time-series Charts**: Request volume and latency trends over time
3. **Distribution Charts**: Request breakdown by group, auth method, API key
4. **Performance Heatmaps**: Latency distribution across different dimensions
5. **Error Analysis**: Detailed error categorization and patterns

## 🚀 Next Steps

1. **Run Tests**: Execute your MinIO rate limiting tests to generate data
2. **Explore Dashboards**: Use HyperDX for interactive data exploration
3. **Custom Analysis**: Use the provided SQL queries for deeper insights
4. **Set Up Alerts**: Configure additional alerts based on your SLA requirements
5. **Scale**: Adjust ClickHouse resources based on your data volume

---

For technical details about the MinIO rate limiting system, see the main [README.md](../../README.md).

For ClickHouse query examples, see [query-examples.sql](query-examples.sql).