#!/usr/bin/env python3
"""
Advanced test script for HAProxy MinIO rate limiting with AWS authentication simulation
"""
import requests
import time
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import hashlib
import hmac
from datetime import datetime
import urllib.parse

class S3AuthSimulator:
    """Simulate AWS S3 authentication headers for testing"""
    
    def __init__(self, access_key, secret_key="dummy-secret"):
        self.access_key = access_key
        self.secret_key = secret_key
    
    def create_v4_auth_header(self, method="GET", path="/", host="localhost"):
        """Create AWS Signature V4 authorization header"""
        # Simplified V4 signature simulation for testing
        timestamp = datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')
        date_stamp = datetime.utcnow().strftime('%Y%m%d')
        
        credential = f"{self.access_key}/{date_stamp}/us-east-1/s3/aws4_request"
        
        # This is a simplified version - in real scenarios, proper signing is required
        auth_header = f"AWS4-HMAC-SHA256 Credential={credential}, SignedHeaders=host;x-amz-date, Signature=dummy-signature"
        
        return {
            'Authorization': auth_header,
            'X-Amz-Date': timestamp,
            'Host': host
        }
    
    def create_v2_auth_header(self, method="GET", path="/"):
        """Create AWS Signature V2 authorization header"""
        # Simplified V2 signature simulation
        signature = "dummy-signature-v2"
        auth_header = f"AWS {self.access_key}:{signature}"
        
        return {
            'Authorization': auth_header,
            'Date': datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S GMT')
        }
    
    def create_presigned_url_params(self, method="GET", expires=3600):
        """Create pre-signed URL parameters"""
        timestamp = datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')
        date_stamp = datetime.utcnow().strftime('%Y%m%d')
        
        params = {
            'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
            'X-Amz-Credential': f"{self.access_key}/{date_stamp}/us-east-1/s3/aws4_request",
            'X-Amz-Date': timestamp,
            'X-Amz-Expires': str(expires),
            'X-Amz-SignedHeaders': 'host',
            'X-Amz-Signature': 'dummy-presigned-signature'
        }
        
        return params

def test_request(base_url, auth_method="v4", api_key="test-key", method="GET", path="/test-bucket/test-object"):
    """Make a test request with specified authentication method"""
    url = f"{base_url}{path}"
    
    auth_sim = S3AuthSimulator(api_key)
    headers = {'User-Agent': 'test-client/2.0'}
    params = {}
    
    if auth_method == "v4":
        headers.update(auth_sim.create_v4_auth_header(method, path))
    elif auth_method == "v2":
        headers.update(auth_sim.create_v2_auth_header(method, path))
    elif auth_method == "presigned":
        params.update(auth_sim.create_presigned_url_params(method))
    elif auth_method == "query_v2":
        params['AWSAccessKeyId'] = api_key
        params['Signature'] = 'dummy-signature'
    elif auth_method == "custom":
        headers['X-API-Key'] = api_key
    
    try:
        response = requests.request(method, url, headers=headers, params=params, timeout=5)
        
        # Extract rate limiting information from headers
        rate_info = {}
        for header, value in response.headers.items():
            if 'rate' in header.lower() or 'api-key' in header.lower() or 'auth' in header.lower():
                rate_info[header] = value
        
        return {
            'status_code': response.status_code,
            'rate_info': rate_info,
            'api_key': api_key,
            'auth_method': auth_method,
            'method': method,
            'timestamp': time.time(),
            'response_time': response.elapsed.total_seconds()
        }
    except Exception as e:
        return {
            'error': str(e),
            'api_key': api_key,
            'auth_method': auth_method,
            'method': method,
            'timestamp': time.time()
        }

def run_group_comparison_test(base_url, duration=60):
    """Test different API key groups to compare rate limits"""
    test_keys = {
        'test-premium-key': 'premium',
        'test-standard-key': 'standard', 
        'test-basic-key': 'basic',
        'unknown-key': 'unknown'
    }
    
    print(f"Running group comparison test for {duration} seconds...")
    print("=" * 60)
    
    results = {}
    
    with ThreadPoolExecutor(max_workers=len(test_keys)) as executor:
        futures = []
        
        for api_key, expected_group in test_keys.items():
            future = executor.submit(run_sustained_test, base_url, api_key, 'v4', duration, 20)  # 20 req/s
            futures.append((future, api_key, expected_group))
        
        for future, api_key, expected_group in futures:
            result = future.result()
            results[api_key] = {
                'expected_group': expected_group,
                'results': result
            }
    
    # Analyze and display results
    print(f"\nGroup Comparison Results:")
    print("-" * 60)
    for api_key, data in results.items():
        result = data['results']
        expected_group = data['expected_group']
        
        success_rate = result['success_count'] / result['total_requests'] * 100 if result['total_requests'] > 0 else 0
        
        print(f"API Key: {api_key}")
        print(f"  Expected Group: {expected_group}")
        print(f"  Detected Group: {result.get('detected_group', 'N/A')}")
        print(f"  Success Rate: {success_rate:.1f}% ({result['success_count']}/{result['total_requests']})")
        print(f"  Rate Limited: {result['rate_limited_count']}")
        print(f"  Average Response Time: {result['avg_response_time']:.3f}s")
        print()

def run_sustained_test(base_url, api_key, auth_method, duration, rate):
    """Run sustained test for a single API key"""
    results = []
    start_time = time.time()
    
    with ThreadPoolExecutor(max_workers=10) as executor:
        while time.time() - start_time < duration:
            batch_start = time.time()
            
            # Submit batch of requests
            futures = []
            for _ in range(rate):
                future = executor.submit(test_request, base_url, auth_method, api_key)
                futures.append(future)
            
            # Collect results
            for future in futures:
                result = future.result()
                results.append(result)
            
            # Wait to maintain rate
            elapsed = time.time() - batch_start
            if elapsed < 1.0:
                time.sleep(1.0 - elapsed)
    
    # Analyze results
    success_count = len([r for r in results if r.get('status_code') == 200])
    rate_limited_count = len([r for r in results if r.get('status_code') == 429])
    error_count = len([r for r in results if 'error' in r])
    
    # Get detected group from first successful response
    detected_group = None
    for result in results:
        if result.get('rate_info', {}).get('X-RateLimit-Group'):
            detected_group = result['rate_info']['X-RateLimit-Group']
            break
    
    # Calculate average response time
    response_times = [r['response_time'] for r in results if 'response_time' in r]
    avg_response_time = sum(response_times) / len(response_times) if response_times else 0
    
    return {
        'total_requests': len(results),
        'success_count': success_count,
        'rate_limited_count': rate_limited_count,
        'error_count': error_count,
        'detected_group': detected_group,
        'avg_response_time': avg_response_time,
        'results': results
    }

def test_auth_methods(base_url, api_key="test-premium-key"):
    """Test different authentication methods"""
    auth_methods = ['v4', 'v2', 'presigned', 'query_v2', 'custom']
    
    print(f"Testing authentication methods with API key: {api_key}")
    print("=" * 60)
    
    for auth_method in auth_methods:
        print(f"\nTesting {auth_method.upper()} authentication...")
        result = test_request(base_url, auth_method, api_key)
        
        if 'error' in result:
            print(f"  ERROR: {result['error']}")
        else:
            print(f"  Status: {result['status_code']}")
            print(f"  Detected Auth Method: {result['rate_info'].get('X-Auth-Method', 'N/A')}")
            print(f"  Detected Group: {result['rate_info'].get('X-RateLimit-Group', 'N/A')}")
            print(f"  Rate Limit (per min): {result['rate_info'].get('X-RateLimit-Limit-Per-Minute', 'N/A')}")

def show_rate_limit_status(base_url, api_keys):
    """Show current rate limit status for multiple API keys"""
    print("Current Rate Limit Status")
    print("=" * 50)
    
    for api_key in api_keys:
        result = test_request(base_url, "v4", api_key)
        if 'error' not in result:
            rate_info = result.get('rate_info', {})
            print(f"\nAPI Key: {api_key}")
            print(f"  Group: {rate_info.get('X-RateLimit-Group', 'N/A')}")
            print(f"  Limit/min: {rate_info.get('X-RateLimit-Limit-Per-Minute', 'N/A')}")
            print(f"  Current/min: {rate_info.get('X-RateLimit-Current-Per-Minute', 'N/A')}")
            print(f"  Remaining/min: {rate_info.get('X-RateLimit-Remaining-Per-Minute', 'N/A')}")
            print(f"  Burst limit/sec: {rate_info.get('X-RateLimit-Limit-Per-Second', 'N/A')}")

def main():
    parser = argparse.ArgumentParser(description='Advanced HAProxy MinIO Rate Limiting Test')
    parser.add_argument('--url', default='http://localhost', help='HAProxy base URL')
    parser.add_argument('--test-type', default='group-comparison', 
                       choices=['single', 'auth-methods', 'group-comparison', 'sustained', 'status'],
                       help='Test type to run')
    parser.add_argument('--api-key', default='test-premium-key', help='API key for single tests')
    parser.add_argument('--auth-method', default='v4', choices=['v4', 'v2', 'presigned', 'query_v2', 'custom'],
                       help='Authentication method')
    parser.add_argument('--rate', type=int, default=20, help='Requests per second')
    parser.add_argument('--duration', type=int, default=60, help='Test duration in seconds')
    parser.add_argument('--method', default='GET', choices=['GET', 'PUT', 'POST'], help='HTTP method')
    
    args = parser.parse_args()
    
    print(f"Advanced HAProxy MinIO Rate Limiting Test")
    print(f"Target: {args.url}")
    print(f"Test Type: {args.test_type}")
    print("=" * 60)
    
    if args.test_type == 'single':
        result = test_request(args.url, args.auth_method, args.api_key, args.method)
        print(json.dumps(result, indent=2))
        
    elif args.test_type == 'auth-methods':
        test_auth_methods(args.url, args.api_key)
        
    elif args.test_type == 'group-comparison':
        run_group_comparison_test(args.url, args.duration)
        
    elif args.test_type == 'sustained':
        result = run_sustained_test(args.url, args.api_key, args.auth_method, args.duration, args.rate)
        print(f"Sustained test results for {args.api_key}:")
        print(f"  Total requests: {result['total_requests']}")
        print(f"  Success rate: {result['success_count']/result['total_requests']*100:.1f}%")
        print(f"  Rate limited: {result['rate_limited_count']}")
        print(f"  Average response time: {result['avg_response_time']:.3f}s")
        print(f"  Detected group: {result['detected_group']}")
        
    elif args.test_type == 'status':
        api_keys = ['test-premium-key', 'test-standard-key', 'test-basic-key', 'unknown-key']
        show_rate_limit_status(args.url, api_keys)

if __name__ == '__main__':
    main()