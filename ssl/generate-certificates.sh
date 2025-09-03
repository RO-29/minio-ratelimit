#!/bin/bash

# SSL Certificate Generation Script for HAProxy MinIO Rate Limiting

CERT_DIR="/Users/rohit/minio-ratelimit/ssl/certs"
DOMAIN="localhost"
COUNTRY="US"
STATE="CA"
CITY="San Francisco"
ORG="MinIO Rate Limiting"
OU="Development"

echo "Creating SSL certificates for HAProxy MinIO Rate Limiting..."
echo "============================================================"

# Create certificate directory
mkdir -p "$CERT_DIR"

# Generate private key
echo "1. Generating private key..."
openssl genrsa -out "$CERT_DIR/haproxy.key" 2048

# Generate certificate signing request
echo "2. Generating certificate signing request..."
openssl req -new -key "$CERT_DIR/haproxy.key" -out "$CERT_DIR/haproxy.csr" \
    -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/OU=$OU/CN=$DOMAIN"

# Generate self-signed certificate
echo "3. Generating self-signed certificate..."
openssl x509 -req -days 365 -in "$CERT_DIR/haproxy.csr" \
    -signkey "$CERT_DIR/haproxy.key" -out "$CERT_DIR/haproxy.crt" \
    -extensions v3_req -extfile <(
cat <<EOF
[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = localhost
DNS.2 = *.localhost
IP.1 = 127.0.0.1
IP.2 = ::1
EOF
)

# Combine certificate and key for HAProxy
echo "4. Creating combined PEM file for HAProxy..."
cat "$CERT_DIR/haproxy.crt" "$CERT_DIR/haproxy.key" > "$CERT_DIR/haproxy.pem"

# Set appropriate permissions
chmod 600 "$CERT_DIR/haproxy.key"
chmod 644 "$CERT_DIR/haproxy.crt"
chmod 600 "$CERT_DIR/haproxy.pem"

echo ""
echo "✅ SSL certificates generated successfully!"
echo ""
echo "Files created:"
echo "  - Private Key: $CERT_DIR/haproxy.key"
echo "  - Certificate: $CERT_DIR/haproxy.crt"
echo "  - Combined PEM: $CERT_DIR/haproxy.pem (for HAProxy)"
echo ""
echo "Certificate Details:"
openssl x509 -in "$CERT_DIR/haproxy.crt" -text -noout | grep -E "(Subject:|Not Before|Not After|DNS:|IP Address:)"
echo ""
echo "🔐 HAProxy will use: $CERT_DIR/haproxy.pem"