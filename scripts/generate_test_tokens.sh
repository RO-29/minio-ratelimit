#!/bin/bash
# Script to generate test tokens for HAProxy rate limiting testing

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Default values
CONFIG_DIR="./haproxy/config"
API_KEY_FILE="${CONFIG_DIR}/api_key_groups.map"
OUTPUT_FILE="${CONFIG_DIR}/generated_service_accounts.json"
NUM_ACCOUNTS=3

# Generate random API keys
function generate_random_key() {
    # Generate a 20-character random string
    local length=20
    local chars="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local key=""

    for i in $(seq 1 $length); do
        local rand=$(( $RANDOM % ${#chars} ))
        key="${key}${chars:$rand:1}"
    done

    echo "$key"
}

# Generate random secret
function generate_random_secret() {
    # Generate a 40-character random string
    local length=40
    local chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local secret=""

    for i in $(seq 1 $length); do
        local rand=$(( $RANDOM % ${#chars} ))
        secret="${secret}${chars:$rand:1}"
    done

    echo "$secret"
}

# Check if config directory exists
if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
    echo "${YELLOW}Created config directory: $CONFIG_DIR${RESET}"
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -n|--num)
        NUM_ACCOUNTS="$2"
        shift
        shift
        ;;
        -o|--output)
        OUTPUT_FILE="$2"
        shift
        shift
        ;;
        -h|--help)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -n, --num NUM       Number of accounts to generate per tier (default: 3)"
        echo "  -o, --output FILE   Output JSON file (default: $OUTPUT_FILE)"
        echo "  -h, --help          Show this help message"
        exit 0
        ;;
        *)
        echo "${RED}Error: Unknown option $1${RESET}"
        echo "Use -h or --help for usage information"
        exit 1
        ;;
    esac
done

# Create API key groups map if it doesn't exist
if [ ! -f "$API_KEY_FILE" ]; then
    touch "$API_KEY_FILE"
    echo "${YELLOW}Created API key groups map file: $API_KEY_FILE${RESET}"
fi

# Start generating accounts
echo "${BLUE}Generating test service accounts...${RESET}"
echo "Number of accounts per tier: $NUM_ACCOUNTS"

# Start JSON file
cat > "$OUTPUT_FILE" << EOF
{
  "service_accounts": [
EOF

# Generate accounts for each tier
tiers=("basic" "standard" "premium")
first=true

for tier in "${tiers[@]}"; do
    echo "${BLUE}Generating $NUM_ACCOUNTS accounts for $tier tier...${RESET}"

    for i in $(seq 1 $NUM_ACCOUNTS); do
        # Generate access key and secret key
        access_key=$(generate_random_key)
        secret_key=$(generate_random_secret)

        # Add to API key groups map
        echo "$access_key $tier" >> "$API_KEY_FILE"

        # Add to JSON file with comma if not first entry
        if [ "$first" = true ]; then
            first=false
        else
            echo "," >> "$OUTPUT_FILE"
        fi

        cat >> "$OUTPUT_FILE" << EOF
    {
      "access_key": "$access_key",
      "secret_key": "$secret_key",
      "tier": "$tier",
      "description": "$tier tier test account $i"
    }
EOF
    done
done

# Close JSON file
cat >> "$OUTPUT_FILE" << EOF
  ]
}
EOF

echo "${GREEN}✅ Service accounts generated successfully!${RESET}"
echo "API key groups map: $API_KEY_FILE"
echo "Service accounts JSON: $OUTPUT_FILE"

# Generate other map files if they don't exist
RATE_LIMIT_PER_MIN="${CONFIG_DIR}/rate_limits_per_minute.map"
RATE_LIMIT_PER_SEC="${CONFIG_DIR}/rate_limits_per_second.map"

if [ ! -f "$RATE_LIMIT_PER_MIN" ]; then
    echo "${YELLOW}Creating rate limits per minute map...${RESET}"
    echo "basic 100" > "$RATE_LIMIT_PER_MIN"
    echo "standard 1000" >> "$RATE_LIMIT_PER_MIN"
    echo "premium 5000" >> "$RATE_LIMIT_PER_MIN"
fi

if [ ! -f "$RATE_LIMIT_PER_SEC" ]; then
    echo "${YELLOW}Creating rate limits per second map...${RESET}"
    echo "basic 5" > "$RATE_LIMIT_PER_SEC"
    echo "standard 20" >> "$RATE_LIMIT_PER_SEC"
    echo "premium 100" >> "$RATE_LIMIT_PER_SEC"
fi

echo "${GREEN}✅ All configuration files are ready!${RESET}"
