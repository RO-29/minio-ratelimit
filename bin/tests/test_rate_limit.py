#!/usr/bin/env python3
"""
Simple test script for HAProxy MinIO rate limiting
"""
import requests
import time
import argparse
from concurrent.futures import ThreadPoolExecutor
import json

def test_request(base_url, api_key=None, method="GET", path="/test-bucket/"):
    """Make a single test request"""
    url = f"{base_url}{path}"
    
    params = {}
    if api_key:
        params['AWSAccessKeyId'] = api_key
    
    headers = {
        'User-Agent': 'test-client/1.0'
    }
    
    try:
        if method == "GET":
            response = requests.get(url, params=params, headers=headers, timeout=5)
        elif method == "PUT":
            response = requests.put(url, params=params, headers=headers, timeout=5)
        else:
            response = requests.request(method, url, params=params, headers=headers, timeout=5)
            
        return {
            'status_code': response.status_code,
            'headers': dict(response.headers),
            'api_key': api_key,
            'method': method,
            'timestamp': time.time()
        }
    except Exception as e:
        return {
            'error': str(e),
            'api_key': api_key,
            'method': method,
            'timestamp': time.time()
        }

def run_load_test(base_url, api_key, method="GET", requests_per_second=10, duration=30):
    """Run a load test with specified parameters"""
    print(f"Starting load test: {requests_per_second} {method} req/s for {duration}s with API key: {api_key}")
    
    results = []
    start_time = time.time()
    
    with ThreadPoolExecutor(max_workers=20) as executor:
        while time.time() - start_time < duration:
            batch_start = time.time()
            
            # Submit batch of requests
            futures = []
            for _ in range(requests_per_second):
                future = executor.submit(test_request, base_url, api_key, method)
                futures.append(future)
            
            # Collect results
            for future in futures:
                result = future.result()
                results.append(result)
            
            # Wait to maintain rate
            elapsed = time.time() - batch_start
            if elapsed < 1.0:
                time.sleep(1.0 - elapsed)
    
    return results

def analyze_results(results):
    """Analyze test results"""
    success_count = len([r for r in results if r.get('status_code', 0) == 200])
    rate_limited_count = len([r for r in results if r.get('status_code', 0) == 429])
    error_count = len([r for r in results if 'error' in r])
    
    print(f"\nResults Analysis:")
    print(f"Total requests: {len(results)}")
    print(f"Successful (200): {success_count}")
    print(f"Rate limited (429): {rate_limited_count}")
    print(f"Errors: {error_count}")
    
    # Show rate limit headers from a sample response
    rate_limited_responses = [r for r in results if r.get('status_code', 0) == 429]
    if rate_limited_responses:
        print(f"\nSample rate limit response headers:")
        sample = rate_limited_responses[0]
        for key, value in sample.get('headers', {}).items():
            if 'rate' in key.lower() or 'limit' in key.lower():
                print(f"  {key}: {value}")

def main():
    parser = argparse.ArgumentParser(description='Test HAProxy MinIO rate limiting')
    parser.add_argument('--url', default='http://localhost', help='HAProxy base URL')
    parser.add_argument('--api-key', default='test-key', help='API key to use')
    parser.add_argument('--method', default='GET', choices=['GET', 'PUT'], help='HTTP method')
    parser.add_argument('--rate', type=int, default=15, help='Requests per second')
    parser.add_argument('--duration', type=int, default=30, help='Test duration in seconds')
    parser.add_argument('--test-type', default='load', choices=['single', 'load'], help='Test type')
    
    args = parser.parse_args()
    
    if args.test_type == 'single':
        # Single request test
        result = test_request(args.url, args.api_key, args.method)
        print(json.dumps(result, indent=2))
    else:
        # Load test
        results = run_load_test(args.url, args.api_key, args.method, args.rate, args.duration)
        analyze_results(results)

if __name__ == '__main__':
    main()