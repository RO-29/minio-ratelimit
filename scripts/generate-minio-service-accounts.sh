#!/bin/bash

# Generate Real MinIO Service Accounts Script with Bucket Permissions
# Creates 40-50 service accounts across different tiers with proper IAM policies

# Ensure paths are correctly set
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

KEYS_FILE="$PROJECT_ROOT/haproxy/config/generated_service_accounts.json"
MAP_FILE="$PROJECT_ROOT/haproxy/config/api_key_groups.map"
POLICY_DIR="$PROJECT_ROOT/haproxy/config/iam_policies"

# Debug paths
echo "Script directory: $SCRIPT_DIR"
echo "Project root: $PROJECT_ROOT"
echo "Keys file path: $KEYS_FILE"
echo "Map file path: $MAP_FILE"
echo "Policy directory path: $POLICY_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔑 MinIO Service Account Generator (40-50 Keys)${NC}"
echo "================================================="
echo

# Configuration: how many accounts per tier
PREMIUM_COUNT=12
STANDARD_COUNT=20
BASIC_COUNT=18
TOTAL_COUNT=$((PREMIUM_COUNT + STANDARD_COUNT + BASIC_COUNT))

echo -e "${BLUE}Planning to generate:${NC}"
echo "  • Premium tier: $PREMIUM_COUNT accounts"
echo "  • Standard tier: $STANDARD_COUNT accounts"
echo "  • Basic tier: $BASIC_COUNT accounts"
echo "  • Total: $TOTAL_COUNT accounts"
echo

# Ensure MinIO is running
echo -e "${BLUE}Checking MinIO status...${NC}"
if ! docker exec minio-ratelimit-minio-1 mc admin info local >/dev/null 2>&1; then
    echo -e "${RED}❌ MinIO is not accessible. Starting services...${NC}"
    cd "$PROJECT_ROOT" && docker-compose up -d minio
    sleep 10

    # Ensure mc is installed in the container
    docker exec minio-ratelimit-minio-1 wget -q https://dl.min.io/client/mc/release/linux-amd64/mc -O /usr/bin/mc 2>/dev/null
    docker exec minio-ratelimit-minio-1 chmod +x /usr/bin/mc 2>/dev/null

    # Setup MinIO alias with default credentials
    docker exec minio-ratelimit-minio-1 mc alias set local http://localhost:9000 minioadmin minioadmin
fi

echo -e "${GREEN}✅ MinIO is accessible${NC}"

# Create directories
mkdir -p "$PROJECT_ROOT/haproxy/config" "$PROJECT_ROOT/haproxy/config/backups" "$POLICY_DIR"

# Create IAM policies for bucket access
echo -e "${BLUE}Creating IAM policies for bucket access...${NC}"

# Full access policy for service accounts
cat > "$POLICY_DIR/s3-full-access.json" << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::*",
                "arn:aws:s3:::*/*"
            ]
        }
    ]
}
EOF

echo -e "${GREEN}✅ Created IAM policy: s3-full-access${NC}"

# Add the policy to MinIO
docker exec minio-ratelimit-minio-1 mc admin policy create local s3-full-access /dev/stdin < "$POLICY_DIR/s3-full-access.json" 2>/dev/null || true

# Function to create test buckets
create_test_buckets() {
    echo -e "${BLUE}Creating test buckets...${NC}"

    # Ensure mc is available
    if ! docker exec minio-ratelimit-minio-1 which mc >/dev/null 2>&1; then
        echo -e "${YELLOW}Installing MinIO Client (mc) in container...${NC}"
        docker exec minio-ratelimit-minio-1 wget -q https://dl.min.io/client/mc/release/linux-amd64/mc -O /usr/bin/mc
        docker exec minio-ratelimit-minio-1 chmod +x /usr/bin/mc
    fi

    # Verify alias is set
    docker exec minio-ratelimit-minio-1 mc alias set local http://localhost:9000 minioadmin minioadmin >/dev/null 2>&1

    local buckets=("test-bucket" "premium-bucket" "standard-bucket" "basic-bucket" "shared-bucket")

    for bucket in "${buckets[@]}"; do
        docker exec minio-ratelimit-minio-1 mc mb "local/$bucket" >/dev/null 2>&1 || true
        echo -e "${GREEN}✅ Bucket: $bucket${NC}"
    done
}

# Function to generate service account with proper permissions
generate_service_account() {
    local group=$1
    local count=$2
    local total_in_group=$3

    echo -e "${YELLOW}Creating $group service account ($count/$total_in_group)...${NC}"

    # Create service account using MinIO admin
    local output=$(docker exec minio-ratelimit-minio-1 mc admin user svcacct add local minioadmin 2>&1)

    if [[ $? -eq 0 ]]; then
        # Extract access key and secret key from output
        local extracted_access_key=$(echo "$output" | grep "Access Key:" | awk '{print $3}')
        local extracted_secret_key=$(echo "$output" | grep "Secret Key:" | awk '{print $3}')

        # Apply the s3-full-access policy to the service account
        docker exec minio-ratelimit-minio-1 mc admin user svcacct edit local "$extracted_access_key" --policy s3-full-access 2>/dev/null || true

        echo -e "${GREEN}✅ Created service account:${NC}"
        echo "   Access Key: $extracted_access_key"
        echo "   Group: $group"
        echo "   Policy: s3-full-access"

        # Store in JSON format
        cat <<EOF >> "$KEYS_FILE.tmp"
{
    "access_key": "$extracted_access_key",
    "secret_key": "$extracted_secret_key",
    "group": "$group",
    "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "description": "Auto-generated $group tier service account #$count",
    "policy": "s3-full-access"
},
EOF

        # Add to HAProxy map
        echo "$extracted_access_key $group" >> "$MAP_FILE.tmp"

        return 0
    else
        echo -e "${RED}❌ Failed to create service account for $group #$count${NC}"
        echo "$output"
        return 1
    fi
}

# Initialize files
echo "[]" > "$KEYS_FILE"
echo "# HAProxy Map File: API Key to Group Mapping" > "$MAP_FILE.tmp"
echo "# Format: api_key group" >> "$MAP_FILE.tmp"
echo "# Generated: $(date)" >> "$MAP_FILE.tmp"
echo "# Total Keys: $TOTAL_COUNT" >> "$MAP_FILE.tmp"
echo "" >> "$MAP_FILE.tmp"

echo "{" > "$KEYS_FILE.tmp"
echo "  \"service_accounts\": [" >> "$KEYS_FILE.tmp"

# Create test buckets first
create_test_buckets

echo -e "${BLUE}Generating $TOTAL_COUNT service accounts...${NC}"
echo

# Generate Premium accounts
echo -e "${BLUE}=== PREMIUM TIER ($PREMIUM_COUNT accounts) ===${NC}"
for i in $(seq 1 $PREMIUM_COUNT); do
    generate_service_account "premium" "$i" "$PREMIUM_COUNT"
    sleep 1
done

# Generate Standard accounts
echo -e "${BLUE}=== STANDARD TIER ($STANDARD_COUNT accounts) ===${NC}"
for i in $(seq 1 $STANDARD_COUNT); do
    generate_service_account "standard" "$i" "$STANDARD_COUNT"
    sleep 1
done

# Generate Basic accounts
echo -e "${BLUE}=== BASIC TIER ($BASIC_COUNT accounts) ===${NC}"
for i in $(seq 1 $BASIC_COUNT); do
    generate_service_account "basic" "$i" "$BASIC_COUNT"
    sleep 1
done

# Also add default admin for testing
echo "minioadmin premium" >> "$MAP_FILE.tmp"

# Finalize JSON file
sed -i '' '$ s/,$//' "$KEYS_FILE.tmp" 2>/dev/null || sed -i '$ s/,$//' "$KEYS_FILE.tmp" # Handle both macOS and Linux
echo "  ]," >> "$KEYS_FILE.tmp"
echo "  \"metadata\": {" >> "$KEYS_FILE.tmp"
echo "    \"generated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"," >> "$KEYS_FILE.tmp"
echo "    \"generator\": \"generate-service-accounts.sh\"," >> "$KEYS_FILE.tmp"
echo "    \"total_accounts\": $TOTAL_COUNT," >> "$KEYS_FILE.tmp"
echo "    \"premium_count\": $PREMIUM_COUNT," >> "$KEYS_FILE.tmp"
echo "    \"standard_count\": $STANDARD_COUNT," >> "$KEYS_FILE.tmp"
echo "    \"basic_count\": $BASIC_COUNT," >> "$KEYS_FILE.tmp"
echo "    \"version\": \"2.0\"" >> "$KEYS_FILE.tmp"
echo "  }" >> "$KEYS_FILE.tmp"
echo "}" >> "$KEYS_FILE.tmp"

# Move temp files to final locations
mv "$KEYS_FILE.tmp" "$KEYS_FILE"
mv "$MAP_FILE.tmp" "$MAP_FILE"

echo
echo -e "${GREEN}✅ Service accounts generated and saved to:${NC}"
echo "   Keys: $KEYS_FILE"
echo "   Map:  $MAP_FILE"
echo "   Policies: $POLICY_DIR/"

# Hot reload HAProxy
echo -e "${BLUE}Hot reloading HAProxy...${NC}"
if [[ -f "$SCRIPT_DIR/manage-dynamic-limits" ]]; then
    if "$SCRIPT_DIR/manage-dynamic-limits" reload; then
        echo -e "${GREEN}✅ HAProxy reloaded successfully${NC}"
    else
        echo -e "${YELLOW}⚠️  HAProxy reload failed, may need manual restart${NC}"
        echo -e "${YELLOW}Restarting HAProxy containers...${NC}"
        cd "$PROJECT_ROOT" && docker-compose restart haproxy1 haproxy2
    fi
else
    echo -e "${YELLOW}⚠️  manage-dynamic-limits script not found, restarting HAProxy containers...${NC}"
    cd "$PROJECT_ROOT" && docker-compose restart haproxy1 haproxy2
fi

# Display summary
echo
echo -e "${BLUE}📊 Generated Service Accounts Summary:${NC}"
echo "======================================"
echo "Total accounts created: $TOTAL_COUNT"

if [[ -f "$KEYS_FILE" ]]; then
    echo
    echo "Breakdown by tier:"

    premium_actual=$(grep "premium" "$MAP_FILE" | grep -v "minioadmin" | wc -l | tr -d ' ')
    standard_actual=$(grep "standard" "$MAP_FILE" | wc -l | tr -d ' ')
    basic_actual=$(grep "basic" "$MAP_FILE" | wc -l | tr -d ' ')

    echo "  • Premium: $premium_actual accounts (limit: 1000 req/min)"
    echo "  • Standard: $standard_actual accounts (limit: 500 req/min)"
    echo "  • Basic: $basic_actual accounts (limit: 100 req/min)"
    echo "  • Admin: 1 account (minioadmin)"

    echo
    echo "Sample keys per tier:"
    grep "premium" "$MAP_FILE" | head -3 | while read key group; do
        echo "  • $key ($group)"
    done | head -3

    echo "  ..."

    echo
    echo "Storage locations:"
    echo "  • HAProxy map file: $MAP_FILE"
    echo "  • Service accounts JSON: $KEYS_FILE"
    echo "  • IAM policies: $POLICY_DIR/"

else
    echo -e "${RED}❌ No service accounts file found${NC}"
fi

echo
echo -e "${GREEN}🎯 Ready for comprehensive testing!${NC}"
echo
echo "Next steps:"
echo "1. cd cmd/ratelimit-test && build/ratelimit-test -duration=30s -accounts=2"
