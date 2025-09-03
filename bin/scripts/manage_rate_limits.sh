#!/bin/bash

# Rate limit management script
CONFIG_FILE="./api_key_groups.conf"
BACKUP_DIR="./backups"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to show usage
usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  add-key <api_key> <group>     Add or update API key with group"
    echo "  remove-key <api_key>          Remove API key"
    echo "  list-keys [group]             List all keys or keys in specific group"
    echo "  change-group <api_key> <new_group>  Change API key group"
    echo "  backup                        Create backup of current configuration"
    echo "  restore <backup_file>         Restore from backup"
    echo "  validate                      Validate configuration file"
    echo "  stats                         Show HAProxy statistics"
    echo ""
    echo "Groups: premium, standard, basic"
    echo ""
    echo "Examples:"
    echo "  $0 add-key AKIAIOSFODNN7EXAMPLE premium"
    echo "  $0 remove-key old-key"
    echo "  $0 list-keys premium"
    echo "  $0 change-group test-key standard"
}

# Function to backup configuration
backup_config() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/api_key_groups_$timestamp.conf"
    
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "$backup_file"
        echo "Backup created: $backup_file"
    else
        echo "Error: Configuration file not found"
        exit 1
    fi
}

# Function to validate configuration
validate_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Configuration file not found"
        return 1
    fi
    
    local errors=0
    local line_num=0
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip comments and empty lines
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
            continue
        fi
        
        # Check format: KEY:GROUP
        if [[ ! "$line" =~ ^[^:]+:(premium|standard|basic)[[:space:]]*$ ]]; then
            echo "Error line $line_num: Invalid format '$line'"
            echo "Expected format: API_KEY:GROUP (where GROUP is premium, standard, or basic)"
            ((errors++))
        fi
    done < "$CONFIG_FILE"
    
    if [ $errors -eq 0 ]; then
        echo "Configuration file is valid"
        return 0
    else
        echo "Configuration file has $errors errors"
        return 1
    fi
}

# Function to add or update API key
add_key() {
    local api_key="$1"
    local group="$2"
    
    if [ -z "$api_key" ] || [ -z "$group" ]; then
        echo "Error: Both API key and group are required"
        usage
        exit 1
    fi
    
    if [[ ! "$group" =~ ^(premium|standard|basic)$ ]]; then
        echo "Error: Invalid group. Must be: premium, standard, or basic"
        exit 1
    fi
    
    # Create backup first
    backup_config
    
    # Remove existing entry if it exists
    if [ -f "$CONFIG_FILE" ]; then
        grep -v "^$api_key:" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" || true
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    fi
    
    # Add new entry
    echo "$api_key:$group" >> "$CONFIG_FILE"
    echo "Added/Updated: $api_key -> $group"
    
    validate_config
}

# Function to remove API key
remove_key() {
    local api_key="$1"
    
    if [ -z "$api_key" ]; then
        echo "Error: API key is required"
        usage
        exit 1
    fi
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Configuration file not found"
        exit 1
    fi
    
    # Create backup first
    backup_config
    
    # Remove the key
    if grep -q "^$api_key:" "$CONFIG_FILE"; then
        grep -v "^$api_key:" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        echo "Removed: $api_key"
    else
        echo "Warning: API key not found: $api_key"
    fi
}

# Function to list keys
list_keys() {
    local group="$1"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Configuration file not found"
        exit 1
    fi
    
    if [ -n "$group" ]; then
        echo "API keys in group '$group':"
        grep ":$group$" "$CONFIG_FILE" | while IFS=: read -r key grp; do
            echo "  $key"
        done
    else
        echo "All API keys:"
        grep -v "^[[:space:]]*#\|^[[:space:]]*$" "$CONFIG_FILE" | while IFS=: read -r key group; do
            printf "  %-30s -> %s\n" "$key" "$group"
        done
    fi
}

# Function to change group
change_group() {
    local api_key="$1"
    local new_group="$2"
    
    if [ -z "$api_key" ] || [ -z "$new_group" ]; then
        echo "Error: Both API key and new group are required"
        usage
        exit 1
    fi
    
    if [[ ! "$new_group" =~ ^(premium|standard|basic)$ ]]; then
        echo "Error: Invalid group. Must be: premium, standard, or basic"
        exit 1
    fi
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Configuration file not found"
        exit 1
    fi
    
    if ! grep -q "^$api_key:" "$CONFIG_FILE"; then
        echo "Error: API key not found: $api_key"
        exit 1
    fi
    
    # Create backup first
    backup_config
    
    # Update the group
    sed -i.bak "s/^$api_key:.*$/$api_key:$new_group/" "$CONFIG_FILE"
    rm -f "${CONFIG_FILE}.bak"
    
    echo "Changed: $api_key -> $new_group"
}

# Function to restore from backup
restore_backup() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        echo "Error: Backup file is required"
        echo "Available backups:"
        ls -la "$BACKUP_DIR"/*.conf 2>/dev/null || echo "No backups found"
        exit 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        echo "Error: Backup file not found: $backup_file"
        exit 1
    fi
    
    # Create backup of current config before restoring
    backup_config
    
    # Restore from backup
    cp "$backup_file" "$CONFIG_FILE"
    echo "Restored from: $backup_file"
    
    validate_config
}

# Function to show HAProxy statistics
show_stats() {
    echo "HAProxy Statistics:"
    echo "=================="
    
    # Try to connect to HAProxy stats socket
    local socket1="/tmp/haproxy1.sock"
    local socket2="/tmp/haproxy2.sock"
    
    if command -v socat >/dev/null 2>&1; then
        echo "Attempting to connect to HAProxy instances..."
        
        # Check if running in Docker
        if command -v docker >/dev/null 2>&1; then
            echo "HAProxy Instance 1:"
            docker exec haproxy1 sh -c 'echo "show stat" | socat stdio /var/run/haproxy.sock' 2>/dev/null | head -20 || echo "Could not connect to HAProxy instance 1"
            
            echo ""
            echo "HAProxy Instance 2:"
            docker exec haproxy2 sh -c 'echo "show stat" | socat stdio /var/run/haproxy.sock' 2>/dev/null | head -20 || echo "Could not connect to HAProxy instance 2"
        else
            echo "Use: curl http://localhost:8404/stats for HAProxy 1 stats"
            echo "Use: curl http://localhost:8405/stats for HAProxy 2 stats"
        fi
    else
        echo "Visit http://localhost:8404/stats for HAProxy 1 statistics"
        echo "Visit http://localhost:8405/stats for HAProxy 2 statistics"
    fi
}

# Main command processing
case "$1" in
    "add-key")
        add_key "$2" "$3"
        ;;
    "remove-key")
        remove_key "$2"
        ;;
    "list-keys")
        list_keys "$2"
        ;;
    "change-group")
        change_group "$2" "$3"
        ;;
    "backup")
        backup_config
        ;;
    "restore")
        restore_backup "$2"
        ;;
    "validate")
        validate_config
        ;;
    "stats")
        show_stats
        ;;
    *)
        usage
        exit 1
        ;;
esac