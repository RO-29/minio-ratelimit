#!/bin/bash

# SSL Certificate Generation Script for HAProxy MinIO Rate Limiting

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Set the certificate directory relative to the project root (one level up from scripts folder)
CERT_DIR="$SCRIPT_DIR/../haproxy/ssl/certs"
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

# Ensure the directory structure exists for Docker volume mounting
HAPROXY_SSL_DIR="$SCRIPT_DIR/../haproxy/ssl"
if [ ! -d "$HAPROXY_SSL_DIR" ]; then
    mkdir -p "$HAPROXY_SSL_DIR"
    echo "Created directory structure for HAProxy SSL certs at $HAPROXY_SSL_DIR"
fi

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
DNS.3 = haproxy
DNS.4 = haproxy1
DNS.5 = haproxy2
DNS.6 = minio
IP.1 = 127.0.0.1
IP.2 = ::1
IP.3 = 192.168.65.1
IP.4 = 192.168.65.2
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

# Add certificate to macOS trust store
echo ""
echo "Adding certificate to macOS trust store..."
# Create a temporary keychain entry for the certificate
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CERT_DIR/haproxy.crt"
if [ $? -eq 0 ]; then
    echo "✅ Certificate successfully added to macOS trust store"
    echo "⚠️  Note: You may need to restart your browser or applications to apply the changes"
else
    echo "❌ Failed to add certificate to macOS trust store"
    echo "   You may need to run this script with sudo or manually add the certificate"
    echo "   To manually add: open Keychain Access, import $CERT_DIR/haproxy.crt and set to 'Always Trust'"
fi
