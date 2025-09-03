#!/usr/bin/env python3
"""
Rate limiting test script for MinIO S3 API through HAProxy
Tests various API keys and rate limit scenarios
"""

import boto3
import time
import threading
import json
from botocore.config import Config
from botocore.exceptions import ClientError
import argparse
import sys

# Test configurations
TEST_CONFIGS = {
    'premium': {
        'access_key': 'test-premium-key',
        'secret_key': 'test-premium-secret',
        'expected_limit': 1000,  # requests per minute
        'description': 'Premium tier - 1000 req/min'
    },
    'standard': {
        'access_key': 'test-standard-key', 
        'secret_key': 'test-standard-secret',
        'expected_limit': 500,   # requests per minute
        'description': 'Standard tier - 500 req/min'
    },
    'basic': {
        'access_key': 'test-basic-key',
        'secret_key': 'test-basic-secret', 
        'expected_limit': 100,   # requests per minute
        'description': 'Basic tier - 100 req/min'
    }
}

class RateLimitTester:
    def __init__(self, endpoint_url='http://localhost', bucket_name='test-bucket'):
        self.endpoint_url = endpoint_url
        self.bucket_name = bucket_name
        self.results = {}
        
    def create_s3_client(self, access_key, secret_key):
        """Create S3 client with specific credentials"""
        config = Config(
            region_name='us-east-1',
            signature_version='s3v4',
            retries={'max_attempts': 1}
        )
        
        return boto3.client(
            's3',
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            endpoint_url=self.endpoint_url,
            config=config
        )
    
    def test_api_key_extraction(self):
        """Test that API keys are properly extracted from different request types"""
        print("\n=== Testing API Key Extraction ===")
        
        for tier, config in TEST_CONFIGS.items():
            print(f"\nTesting {tier} tier ({config['description']})...")
            
            client = self.create_s3_client(config['access_key'], config['secret_key'])
            
            try:
                # Test bucket operations
                print(f"  Testing bucket list with {config['access_key']}...")
                response = client.list_buckets()
                print(f"    ✓ Bucket list successful")
                
                # Check rate limit headers if present
                if hasattr(response, 'ResponseMetadata'):
                    headers = response['ResponseMetadata'].get('HTTPHeaders', {})
                    if 'x-ratelimit-limit' in headers:
                        print(f"    Rate limit: {headers['x-ratelimit-limit']}")
                        print(f"    Remaining: {headers.get('x-ratelimit-remaining', 'N/A')}")
                
            except ClientError as e:
                error_code = e.response['Error']['Code']
                if error_code == 'SlowDown':
                    print(f"    ✓ Rate limit applied (429 SlowDown)")
                else:
                    print(f"    ⚠ Error: {error_code}")
            except Exception as e:
                print(f"    ⚠ Connection error: {str(e)}")
    
    def test_rate_limiting(self, tier, duration_seconds=60, target_rps=20):
        """Test rate limiting for a specific tier"""
        config = TEST_CONFIGS[tier]
        client = self.create_s3_client(config['access_key'], config['secret_key'])
        
        print(f"\n=== Testing {tier.upper()} Rate Limiting ===")
        print(f"Target: {target_rps} req/sec for {duration_seconds} seconds")
        print(f"Expected limit: {config['expected_limit']} req/min")
        
        results = {
            'successful': 0,
            'rate_limited': 0,
            'errors': 0,
            'response_times': [],
            'start_time': time.time()
        }
        
        def make_request():
            try:
                start = time.time()
                response = client.list_buckets()
                end = time.time()
                
                results['response_times'].append(end - start)
                results['successful'] += 1
                
                # Check for rate limit headers
                headers = response['ResponseMetadata'].get('HTTPHeaders', {})
                if 'x-ratelimit-remaining' in headers:
                    remaining = headers['x-ratelimit-remaining']
                    if int(remaining) < 10:
                        print(f"    Low remaining requests: {remaining}")
                        
            except ClientError as e:
                if e.response['Error']['Code'] == 'SlowDown':
                    results['rate_limited'] += 1
                    print(f"    Rate limited at {time.time() - results['start_time']:.1f}s")
                else:
                    results['errors'] += 1
                    print(f"    Error: {e.response['Error']['Code']}")
            except Exception as e:
                results['errors'] += 1
                print(f"    Connection error: {str(e)}")
        
        # Send requests at target rate
        interval = 1.0 / target_rps
        end_time = time.time() + duration_seconds
        
        while time.time() < end_time:
            request_start = time.time()
            make_request()
            
            # Sleep to maintain target rate
            elapsed = time.time() - request_start
            if elapsed < interval:
                time.sleep(interval - elapsed)
        
        # Calculate results
        total_requests = results['successful'] + results['rate_limited'] + results['errors']
        actual_duration = time.time() - results['start_time']
        actual_rps = total_requests / actual_duration
        
        print(f"\nResults for {tier}:")
        print(f"  Duration: {actual_duration:.1f}s")
        print(f"  Total requests: {total_requests}")
        print(f"  Successful: {results['successful']}")
        print(f"  Rate limited (429): {results['rate_limited']}")
        print(f"  Other errors: {results['errors']}")
        print(f"  Actual RPS: {actual_rps:.2f}")
        print(f"  Avg response time: {sum(results['response_times'])/len(results['response_times']):.3f}s" if results['response_times'] else "N/A")
        
        # Analyze rate limiting behavior
        expected_per_second = config['expected_limit'] / 60
        if results['rate_limited'] > 0:
            print(f"  ✓ Rate limiting active (expected at >{expected_per_second:.1f} req/sec)")
        elif actual_rps > expected_per_second:
            print(f"  ⚠ Rate limiting may not be working (sent {actual_rps:.1f} req/sec)")
        else:
            print(f"  ✓ Below rate limit threshold")
        
        self.results[tier] = results
        return results
    
    def test_concurrent_clients(self, tier, num_clients=5, duration_seconds=30):
        """Test rate limiting with concurrent clients using same API key"""
        print(f"\n=== Testing Concurrent Clients ({tier.upper()}) ===")
        print(f"Clients: {num_clients}, Duration: {duration_seconds}s")
        
        config = TEST_CONFIGS[tier]
        results = []
        threads = []
        
        def client_worker(client_id):
            client = self.create_s3_client(config['access_key'], config['secret_key'])
            client_results = {'successful': 0, 'rate_limited': 0, 'errors': 0}
            
            end_time = time.time() + duration_seconds
            while time.time() < end_time:
                try:
                    client.list_buckets()
                    client_results['successful'] += 1
                except ClientError as e:
                    if e.response['Error']['Code'] == 'SlowDown':
                        client_results['rate_limited'] += 1
                    else:
                        client_results['errors'] += 1
                except:
                    client_results['errors'] += 1
                
                time.sleep(0.1)  # Small delay between requests
            
            results.append((client_id, client_results))
            print(f"    Client {client_id}: {client_results['successful']} success, {client_results['rate_limited']} rate-limited")
        
        # Start all client threads
        for i in range(num_clients):
            thread = threading.Thread(target=client_worker, args=(i+1,))
            threads.append(thread)
            thread.start()
        
        # Wait for all threads to complete
        for thread in threads:
            thread.join()
        
        # Aggregate results
        total_success = sum(r[1]['successful'] for r in results)
        total_rate_limited = sum(r[1]['rate_limited'] for r in results)
        total_errors = sum(r[1]['errors'] for r in results)
        total_requests = total_success + total_rate_limited + total_errors
        
        print(f"\nConcurrent test results:")
        print(f"  Total requests: {total_requests}")
        print(f"  Successful: {total_success}")
        print(f"  Rate limited: {total_rate_limited}")
        print(f"  Errors: {total_errors}")
        print(f"  Rate limited %: {(total_rate_limited/total_requests)*100:.1f}%")
    
    def generate_report(self):
        """Generate a summary report of all tests"""
        print("\n" + "="*50)
        print("RATE LIMITING TEST SUMMARY")
        print("="*50)
        
        for tier, results in self.results.items():
            if results:
                config = TEST_CONFIGS[tier]
                total = results['successful'] + results['rate_limited'] + results['errors']
                
                print(f"\n{tier.upper()} Tier ({config['description']}):")
                print(f"  Expected limit: {config['expected_limit']} req/min")
                print(f"  Total requests: {total}")
                print(f"  Success rate: {(results['successful']/total)*100:.1f}%")
                print(f"  Rate limited: {(results['rate_limited']/total)*100:.1f}%")
                
                if results['rate_limited'] > 0:
                    print(f"  ✓ Rate limiting is working")
                else:
                    print(f"  ⚠ Rate limiting may need adjustment")

def main():
    parser = argparse.ArgumentParser(description='Test MinIO rate limiting through HAProxy')
    parser.add_argument('--endpoint', default='http://localhost', 
                       help='HAProxy endpoint URL (default: http://localhost)')
    parser.add_argument('--duration', type=int, default=30,
                       help='Test duration in seconds (default: 30)')
    parser.add_argument('--tier', choices=['premium', 'standard', 'basic', 'all'], 
                       default='all', help='Test specific tier or all')
    parser.add_argument('--concurrent', action='store_true',
                       help='Run concurrent client tests')
    parser.add_argument('--rps', type=int, default=10,
                       help='Target requests per second (default: 10)')
    
    args = parser.parse_args()
    
    tester = RateLimitTester(endpoint_url=args.endpoint)
    
    # Test API key extraction first
    tester.test_api_key_extraction()
    
    # Test rate limiting
    if args.tier == 'all':
        tiers = ['basic', 'standard', 'premium']
    else:
        tiers = [args.tier]
    
    for tier in tiers:
        tester.test_rate_limiting(tier, args.duration, args.rps)
        
        if args.concurrent:
            tester.test_concurrent_clients(tier, num_clients=3, duration_seconds=args.duration//2)
    
    # Generate final report
    tester.generate_report()

if __name__ == '__main__':
    main()