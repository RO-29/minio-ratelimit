#!/usr/bin/env python3
"""Test PUT/GET rate limiting vs other methods"""
import requests

def test_method(method, api_key="AKIAIOSFODNN7EXAMPLE"):
    headers = {"Authorization": f"AWS {api_key}:signature"}
    try:
        response = requests.request(method, "http://localhost/bucket/object", headers=headers, timeout=5)
        return {
            'method': method,
            'status': response.status_code,
            'rate_limited': response.status_code == 429,
            'headers': {k: v for k, v in response.headers.items() if 'rate' in k.lower()}
        }
    except Exception as e:
        return {'method': method, 'error': str(e)}

# Test all methods
methods = ['GET', 'PUT', 'POST', 'DELETE', 'HEAD']
results = []

print("Testing method-specific rate limiting...")
print("=" * 50)

for method in methods:
    for i in range(120):  # Send 120 requests to trigger rate limiting
        result = test_method(method)
        if i == 119:  # Show result of last request
            results.append(result)

for result in results:
    method = result['method']
    rate_limited = result.get('rate_limited', False)
    status = result.get('status', 'ERROR')
    
    expected_rate_limited = method in ['GET', 'PUT']
    
    print(f"{method:6}: Status {status}, Rate Limited: {rate_limited} {'✓' if rate_limited == expected_rate_limited else '✗'}")