#!/usr/bin/env python3

import json
import requests
import time
from datetime import datetime, timezone
import uuid
from typing import Dict, List, Any

class MinIOHyperDXIngester:
    def __init__(self, clickhouse_url="http://localhost:8123", hyperdx_url="http://localhost:8080"):
        self.clickhouse_url = clickhouse_url
        self.hyperdx_url = hyperdx_url
        self.database = "minio_logs"
        
    def setup_database(self):
        """Create database and tables optimized for MinIO log analysis"""
        print("🔧 Setting up ClickHouse database and tables...")
        
        # Create database
        self.execute_sql("CREATE DATABASE IF NOT EXISTS minio_logs")
        
        # Create main test results table with JSON column
        test_results_sql = f"""
        CREATE TABLE IF NOT EXISTS {self.database}.test_results (
            timestamp DateTime64(3) DEFAULT now64(),
            test_id String,
            test_group LowCardinality(String),
            api_key String,
            method LowCardinality(String),
            requests_sent UInt32,
            success_count UInt32,
            rate_limited_count UInt32,
            error_count UInt32,
            avg_latency_ms Float64,
            auth_method LowCardinality(String),
            rate_limit_group LowCardinality(String),
            burst_hits UInt32,
            minute_hits UInt32,
            effective_limit UInt32,
            observed_bursts UInt32,
            success_rate Float64,
            -- New JSON column for rich data
            raw_data JSON,
            -- Rate limit details as nested structure
            rate_limit_details JSON,
            -- Error details as JSON
            error_details JSON,
            -- Header captures as JSON array
            header_captures JSON
        ) ENGINE = MergeTree()
        ORDER BY (timestamp, test_group, api_key)
        PARTITION BY toYYYYMM(timestamp)
        TTL timestamp + INTERVAL 90 DAY
        """
        
        self.execute_sql(test_results_sql)
        
        # Create throttle events table for detailed analysis
        throttle_events_sql = f"""
        CREATE TABLE IF NOT EXISTS {self.database}.throttle_events (
            timestamp DateTime64(3),
            test_group LowCardinality(String),
            method LowCardinality(String),
            remaining_requests UInt32,
            reset_in_seconds UInt32,
            event_data JSON
        ) ENGINE = MergeTree()
        ORDER BY (timestamp, test_group)
        PARTITION BY toYYYYMM(timestamp)
        TTL timestamp + INTERVAL 30 DAY
        """
        
        self.execute_sql(throttle_events_sql)
        
        # Create summary table for aggregated metrics
        summary_sql = f"""
        CREATE TABLE IF NOT EXISTS {self.database}.test_summary (
            timestamp DateTime64(3) DEFAULT now64(),
            total_tests UInt32,
            duration_seconds Float64,
            total_requests UInt32,
            total_success UInt32,
            total_limited UInt32,
            total_errors UInt32,
            auth_methods JSON,
            summary_data JSON
        ) ENGINE = MergeTree()
        ORDER BY timestamp
        PARTITION BY toYYYYMM(timestamp)
        TTL timestamp + INTERVAL 180 DAY
        """
        
        self.execute_sql(summary_sql)
        
        print("✅ Database setup complete!")
        
    def execute_sql(self, query: str) -> str:
        """Execute SQL query against ClickHouse"""
        try:
            # Use basic auth with empty password for HyperDX ClickHouse
            response = requests.post(self.clickhouse_url, data=query, 
                                   auth=('default', ''), timeout=30)
            if response.status_code == 200:
                return response.text
            else:
                print(f"❌ SQL Error: {response.text}")
                return ""
        except requests.exceptions.RequestException as e:
            print(f"❌ Connection error: {e}")
            return ""
    
    def ingest_comprehensive_results(self, json_file_path: str = "comprehensive_results.json"):
        """Ingest comprehensive_results.json into HyperDX ClickStack"""
        print(f"📥 Ingesting {json_file_path}...")
        
        try:
            with open(json_file_path, 'r') as f:
                data = json.load(f)
        except FileNotFoundError:
            print(f"❌ File {json_file_path} not found")
            return False
        except json.JSONDecodeError as e:
            print(f"❌ JSON decode error: {e}")
            return False
        
        # Extract timestamp from the data
        current_timestamp = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')
        
        # 1. Insert summary data
        if 'summary' in data:
            self.ingest_summary(data['summary'], current_timestamp)
        
        # 2. Insert detailed group results
        if 'summary' in data and 'ByGroup' in data['summary']:
            self.ingest_group_results(data['summary']['ByGroup'], current_timestamp)
        
        # 3. Insert throttle events
        if 'summary' in data and 'RateLimitAnalysis' in data['summary']:
            self.ingest_throttle_events(data['summary']['RateLimitAnalysis'], current_timestamp)
        
        return True
    
    def ingest_summary(self, summary: Dict[str, Any], timestamp: str):
        """Insert summary data"""
        duration_seconds = summary.get('Duration', 0) / 1_000_000_000  # Convert nanoseconds to seconds
        
        summary_insert = f"""
        INSERT INTO {self.database}.test_summary 
        (timestamp, total_tests, duration_seconds, total_requests, total_success, total_limited, total_errors, auth_methods, summary_data)
        VALUES 
        ('{timestamp}', {summary.get('TotalTests', 0)}, {duration_seconds}, {summary.get('TotalRequests', 0)}, 
         {summary.get('TotalSuccess', 0)}, {summary.get('TotalLimited', 0)}, {summary.get('TotalErrors', 0)},
         '{json.dumps(summary.get('AuthMethods', {}))}', '{json.dumps(summary)}')
        """
        
        result = self.execute_sql(summary_insert)
        if result == "":
            print("✅ Summary data inserted")
        else:
            print(f"❌ Summary insert error: {result}")
    
    def ingest_group_results(self, groups: Dict[str, Any], timestamp: str):
        """Insert detailed group results using ClickHouse JSON capabilities"""
        print(f"📊 Inserting {len(groups)} group results...")
        
        for group_name, group_data in groups.items():
            test_id = str(uuid.uuid4())
            
            # Extract rate limit analysis if available
            rate_limit_analysis = {}
            if 'RateLimitAnalysis' in group_data:
                rate_limit_analysis = group_data['RateLimitAnalysis']
            
            # Prepare the insert with JSON data
            insert_sql = f"""
            INSERT INTO {self.database}.test_results 
            (timestamp, test_id, test_group, api_key, method, requests_sent, success_count, 
             rate_limited_count, error_count, avg_latency_ms, auth_method, rate_limit_group,
             burst_hits, minute_hits, effective_limit, observed_bursts, success_rate,
             raw_data, rate_limit_details, error_details, header_captures)
            VALUES 
            ('{timestamp}', '{test_id}', '{group_name}', '{group_data.get('APIKey', '')}', 
             '{group_data.get('Method', 'Combined')}', {group_data.get('RequestsSent', 0)},
             {group_data.get('Success', 0)}, {group_data.get('RateLimited', 0)}, 
             {group_data.get('Errors', 0)}, {group_data.get('AvgLatencyMs', 0.0)},
             '{group_data.get('AuthMethod', '')}', '{group_data.get('RateLimitGroup', '')}',
             {group_data.get('BurstHits', 0)}, {group_data.get('MinuteHits', 0)},
             {rate_limit_analysis.get('EffectiveLimit', 0)}, {rate_limit_analysis.get('ObservedBursts', 0)},
             {rate_limit_analysis.get('SuccessRate', 0.0)},
             '{json.dumps(group_data)}',
             '{json.dumps(group_data.get('RateLimitDetails', {}))}',
             '{json.dumps(group_data.get('ErrorDetails', {}))}',
             '{json.dumps(group_data.get('HeaderCaptures', []))}')
            """
            
            result = self.execute_sql(insert_sql)
            if result == "":
                print(f"✅ Inserted {group_name} group data")
            else:
                print(f"❌ Failed to insert {group_name}: {result}")
    
    def ingest_throttle_events(self, rate_limit_analysis: Dict[str, Any], base_timestamp: str):
        """Insert throttle events for detailed rate limiting analysis"""
        print("🚦 Inserting throttle events...")
        
        events_inserted = 0
        for group_name, group_analysis in rate_limit_analysis.items():
            if 'ThrottleEvents' in group_analysis:
                for event in group_analysis['ThrottleEvents']:
                    # Parse the timestamp from the event
                    event_time = datetime.fromisoformat(event['Timestamp'].replace('+05:30', '')).strftime('%Y-%m-%d %H:%M:%S')
                    
                    throttle_insert = f"""
                    INSERT INTO {self.database}.throttle_events 
                    (timestamp, test_group, method, remaining_requests, reset_in_seconds, event_data)
                    VALUES 
                    ('{event_time}', '{event.get('Group', group_name)}', '{event.get('Method', '')}',
                     {event.get('RemainingReqs', 0)}, {event.get('ResetIn', 0)}, 
                     '{json.dumps(event)}')
                    """
                    
                    result = self.execute_sql(throttle_insert)
                    if result == "":
                        events_inserted += 1
        
        print(f"✅ Inserted {events_inserted} throttle events")
    
    def verify_ingestion(self):
        """Verify data was ingested correctly"""
        print("🔍 Verifying data ingestion...")
        
        # Check test results
        results_count = self.execute_sql(f"SELECT count() FROM {self.database}.test_results").strip()
        print(f"✅ Test results: {results_count} records")
        
        # Check throttle events  
        events_count = self.execute_sql(f"SELECT count() FROM {self.database}.throttle_events").strip()
        print(f"✅ Throttle events: {events_count} records")
        
        # Check summary
        summary_count = self.execute_sql(f"SELECT count() FROM {self.database}.test_summary").strip()
        print(f"✅ Summary records: {summary_count} records")
        
        # Show sample data
        print("\n📋 Sample data preview:")
        sample_query = f"""
        SELECT test_group, requests_sent, success_count, rate_limited_count, avg_latency_ms, success_rate
        FROM {self.database}.test_results 
        ORDER BY timestamp DESC 
        LIMIT 5 
        FORMAT PrettyCompact
        """
        sample_data = self.execute_sql(sample_query)
        print(sample_data)
    
    def create_hyperdx_views(self):
        """Create optimized views for HyperDX visualization"""
        print("📊 Creating HyperDX visualization views...")
        
        # Performance overview view
        perf_view = f"""
        CREATE OR REPLACE VIEW {self.database}.performance_overview AS
        SELECT 
            test_group,
            sum(requests_sent) as total_requests,
            sum(success_count) as total_success,
            sum(rate_limited_count) as total_rate_limited,
            sum(error_count) as total_errors,
            round(avg(avg_latency_ms), 2) as avg_latency,
            round(avg(success_rate), 2) as avg_success_rate,
            max(effective_limit) as max_effective_limit,
            sum(observed_bursts) as total_bursts
        FROM {self.database}.test_results
        GROUP BY test_group
        ORDER BY total_requests DESC
        """
        
        self.execute_sql(perf_view)
        
        # Time-series view for trends
        timeseries_view = f"""
        CREATE OR REPLACE VIEW {self.database}.hourly_metrics AS
        SELECT 
            toStartOfHour(timestamp) as hour,
            test_group,
            count() as test_runs,
            sum(requests_sent) as requests,
            sum(success_count) as success,
            sum(rate_limited_count) as rate_limited,
            avg(avg_latency_ms) as avg_latency
        FROM {self.database}.test_results
        GROUP BY hour, test_group
        ORDER BY hour DESC
        """
        
        self.execute_sql(timeseries_view)
        
        # Rate limiting analysis view
        rate_limit_view = f"""
        CREATE OR REPLACE VIEW {self.database}.rate_limit_analysis AS
        SELECT 
            test_group,
            api_key,
            sum(requests_sent) as total_requests,
            sum(rate_limited_count) as total_rate_limited,
            round(sum(rate_limited_count) / sum(requests_sent) * 100, 2) as rate_limit_percentage,
            avg(effective_limit) as avg_limit,
            sum(observed_bursts) as total_bursts,
            round(avg(success_rate), 2) as avg_success_rate
        FROM {self.database}.test_results
        WHERE requests_sent > 0
        GROUP BY test_group, api_key
        ORDER BY rate_limit_percentage DESC
        """
        
        self.execute_sql(rate_limit_view)
        
        print("✅ HyperDX views created")

def main():
    print("🚀 MinIO → HyperDX ClickStack Ingestion Tool")
    print("=" * 50)
    
    ingester = MinIOHyperDXIngester()
    
    # Setup database
    ingester.setup_database()
    
    # Ingest data
    if ingester.ingest_comprehensive_results():
        # Create views
        ingester.create_hyperdx_views()
        
        # Verify ingestion
        ingester.verify_ingestion()
        
        print("\n🎉 Data ingestion completed successfully!")
        print("\n📈 Next steps:")
        print("1. Access HyperDX UI: http://localhost:8080")
        print("2. ClickHouse interface: http://localhost:8123/play")  
        print("3. Use queries from the analysis guide")
        print("4. Explore JSON data with ClickHouse JSON functions")
        
    else:
        print("\n❌ Data ingestion failed!")

if __name__ == "__main__":
    main()