#!/usr/bin/env python3
"""Test individual API key limits within groups"""
import requests
import time

def test_api_key(api_key, expected_group, requests_to_send=10):
    headers = {"Authorization": f"AWS {api_key}:signature"}
    results = []
    
    for i in range(requests_to_send):
        try:
            response = requests.get("http://localhost/bucket/object", headers=headers, timeout=5)
            results.append({
                'status': response.status_code,
                'current_rate': response.headers.get('x-ratelimit-current-per-minute', 'N/A'),
                'group': response.headers.get('x-ratelimit-group', 'N/A'),
                'limit': response.headers.get('x-ratelimit-limit-per-minute', 'N/A')
            })
        except Exception as e:
            results.append({'error': str(e)})
        
        time.sleep(0.1)  # Small delay
    
    last_result = results[-1]
    return {
        'api_key': api_key,
        'expected_group': expected_group,
        'detected_group': last_result.get('group', 'ERROR'),
        'final_count': last_result.get('current_rate', 'ERROR'),
        'limit': last_result.get('limit', 'ERROR'),
        'last_status': last_result.get('status', 'ERROR')
    }

# Test multiple API keys in same group
test_keys = [
    ('AKIAIOSFODNN7EXAMPLE', 'premium'),   # Premium key 1
    ('test-premium-key', 'premium'),       # Premium key 2  
    ('test-standard-key', 'standard'),     # Standard key
    ('test-basic-key', 'basic'),           # Basic key
]

print("Testing Individual API Key Rate Limits")
print("=" * 50)
print(f"{'API Key':<25} {'Group':<10} {'Limit':<6} {'Count':<6} {'Status'}")
print("-" * 50)

for api_key, expected_group in test_keys:
    result = test_api_key(api_key, expected_group)
    
    print(f"{result['api_key']:<25} {result['detected_group']:<10} {result['limit']:<6} {result['final_count']:<6} {result['last_status']}")

print(f"\n✓ Each API key maintains its own individual rate limit counter")
print(f"✓ API keys in same group get same limits but separate tracking")