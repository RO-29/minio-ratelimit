ARG HAPROXY_VERSION=3.0
FROM haproxy:${HAPROXY_VERSION}

# Install socat for HAProxy runtime API (run as root)
USER root
RUN apt-get update && apt-get install -y socat && rm -rf /var/lib/apt/lists/*

# Copy HAProxy configuration
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
COPY lua/ /usr/local/etc/haproxy/
COPY config/ /usr/local/etc/haproxy/config/

# Copy the pre-generated SSL certificates
COPY ssl/certs/ /etc/ssl/certs/

# Note: Configuration validation skipped during build as 'minio' hostname is not available

# Default command
CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
