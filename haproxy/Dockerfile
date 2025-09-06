ARG HAPROXY_VERSION=3.0
FROM haproxy:${HAPROXY_VERSION}

# Install socat for HAProxy runtime API (run as root)
USER root
RUN apt-get update && apt-get install -y socat && rm -rf /var/lib/apt/lists/*

# Copy HAProxy configuration
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
COPY lua/ /usr/local/etc/haproxy/
COPY config/ /usr/local/etc/haproxy/config/

# Create SSL directories
RUN mkdir -p /etc/ssl/certs/

# Install OpenSSL and generate a dummy certificate (will be overridden by volume mount)
RUN apt-get update && apt-get install -y openssl && rm -rf /var/lib/apt/lists/* && \
    openssl req -x509 -newkey rsa:2048 -nodes -keyout /etc/ssl/certs/haproxy.key \
    -out /etc/ssl/certs/haproxy.crt -subj '/C=US/ST=CA/L=SF/O=Test/CN=localhost' -days 365 && \
    cat /etc/ssl/certs/haproxy.crt /etc/ssl/certs/haproxy.key > /etc/ssl/certs/haproxy.pem

# Note: Real certificates will be mounted as volumes from host during container startup

# Note: Configuration validation skipped during build as 'minio' hostname is not available

# Default command
CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
