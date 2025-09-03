#!/bin/sh

# Configuration file watcher for hot reload
CONFIG_FILE="/etc/haproxy/api_key_groups.conf"
HAPROXY1_SOCKET="/var/run/haproxy1/haproxy.sock"
HAPROXY2_SOCKET="/var/run/haproxy2/haproxy.sock"

echo "Starting configuration file watcher..."
echo "Monitoring: $CONFIG_FILE"

# Function to reload HAProxy configuration
reload_haproxy() {
    echo "Configuration file changed, triggering HAProxy reload..."
    
    # Send reload signal to HAProxy instances via stats socket
    if [ -S "$HAPROXY1_SOCKET" ]; then
        echo "Reloading HAProxy instance 1..."
        echo "reload" | socat stdio "$HAPROXY1_SOCKET"
    fi
    
    if [ -S "$HAPROXY2_SOCKET" ]; then
        echo "Reloading HAProxy instance 2..."  
        echo "reload" | socat stdio "$HAPROXY2_SOCKET"
    fi
    
    echo "Reload completed at $(date)"
}

# Initial check
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file $CONFIG_FILE not found"
    exit 1
fi

echo "Initial configuration loaded"

# Watch for file changes
while inotifywait -e modify,move,create,delete "$CONFIG_FILE" 2>/dev/null; do
    sleep 1  # Debounce multiple rapid changes
    reload_haproxy
done