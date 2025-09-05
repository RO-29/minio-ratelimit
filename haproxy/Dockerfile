FROM haproxy:3.0

# Copy HAProxy configuration
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
COPY lua/ /usr/local/etc/haproxy/
COPY config/ /usr/local/etc/haproxy/config/

# Create a self-signed certificate for testing
RUN mkdir -p /etc/ssl/certs/ && \
    openssl req -x509 -newkey rsa:2048 -nodes -keyout /etc/ssl/certs/haproxy.pem \
    -out /etc/ssl/certs/haproxy.pem -days 365 -subj "/CN=localhost"

# Validate configuration
RUN haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg

# Default command
CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
