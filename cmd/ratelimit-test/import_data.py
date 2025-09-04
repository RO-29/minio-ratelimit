#!/usr/bin/env python3

import json
import requests
from datetime import datetime
import uuid

def import_results_to_clickhouse():
    """Import comprehensive_results.json data into ClickHouse"""
    
    # Read the JSON file
    try:
        with open('comprehensive_results.json', 'r') as f:
            data = json.load(f)
    except FileNotFoundError:
        print("❌ comprehensive_results.json not found. Run tests first.")
        return False
    except json.JSONDecodeError as e:
        print(f"❌ JSON decode error: {e}")
        return False

    # Process each group in the summary
    records = []
    if 'summary' in data and 'ByGroup' in data['summary']:
        for group_name, group_data in data['summary']['ByGroup'].items():
            record = {
                'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'test_id': str(uuid.uuid4()),
                'group': group_name,
                'api_key': group_data.get('APIKey', ''),
                'method': group_data.get('Method', 'Combined'),
                'requests_sent': group_data.get('RequestsSent', 0),
                'success_count': group_data.get('Success', 0),
                'rate_limited_count': group_data.get('RateLimited', 0),
                'error_count': group_data.get('Errors', 0),
                'avg_latency_ms': group_data.get('AvgLatencyMs', 0.0),
                'auth_method': group_data.get('AuthMethod', '')
            }
            records.append(record)
    
    if not records:
        print("❌ No data found in comprehensive_results.json")
        return False
    
    print(f"📊 Found {len(records)} records to import")
    
    # Insert data into ClickHouse
    for record in records:
        query = f"""
        INSERT INTO minio_logs.test_results 
        (timestamp, test_id, `group`, api_key, method, requests_sent, success_count, rate_limited_count, error_count, avg_latency_ms, auth_method)
        VALUES 
        ('{record['timestamp']}', '{record['test_id']}', '{record['group']}', '{record['api_key']}', '{record['method']}', 
         {record['requests_sent']}, {record['success_count']}, {record['rate_limited_count']}, {record['error_count']}, 
         {record['avg_latency_ms']}, '{record['auth_method']}')
        """
        
        try:
            response = requests.post('http://localhost:8123/', data=query)
            if response.status_code == 200:
                print(f"✅ Imported {record['group']} group data")
            else:
                print(f"❌ Failed to import {record['group']}: {response.text}")
        except requests.exceptions.RequestException as e:
            print(f"❌ Connection error: {e}")
            return False
    
    return True

def verify_data():
    """Verify data was imported correctly"""
    try:
        response = requests.post('http://localhost:8123/', 
                               data="SELECT count() as total_records FROM minio_logs.test_results")
        if response.status_code == 200:
            count = int(response.text.strip())
            print(f"✅ Verification: {count} records in database")
            
            # Show sample data
            response = requests.post('http://localhost:8123/', 
                                   data="SELECT `group`, requests_sent, success_count, rate_limited_count FROM minio_logs.test_results ORDER BY timestamp DESC LIMIT 5 FORMAT PrettyCompact")
            if response.status_code == 200:
                print("\n📋 Sample data:")
                print(response.text)
            
        else:
            print(f"❌ Verification failed: {response.text}")
    except requests.exceptions.RequestException as e:
        print(f"❌ Verification error: {e}")

if __name__ == "__main__":
    print("🚀 MinIO Test Results Import Tool")
    print("==================================")
    
    if import_results_to_clickhouse():
        print("\n🎉 Data import completed successfully!")
        verify_data()
        
        print("\n📈 Next steps:")
        print("1. Query data: curl 'http://localhost:8123/' -d 'SELECT * FROM minio_logs.test_results'")
        print("2. Web interface: http://localhost:8123/play")
        print("3. Run analysis queries from query-examples.sql")
    else:
        print("\n❌ Data import failed!")