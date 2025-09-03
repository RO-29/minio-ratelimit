#!/bin/bash

# Generate self-signed SSL certificate for testing
# In production, use proper SSL certificates

openssl req -x509 -newkey rsa:4096 -keyout haproxy.key -out haproxy.crt -days 365 -nodes \
  -subj "/C=US/ST=State/L=City/O=Organization/OU=Unit/CN=localhost"

# Combine certificate and key for HAProxy
cat haproxy.crt haproxy.key > haproxy.pem

echo "Self-signed SSL certificate generated: haproxy.pem"
echo "This is for testing only. Use proper certificates in production."