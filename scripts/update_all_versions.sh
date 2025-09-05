#!/bin/bash
# Master script to update all versions in the project

# Set up color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔄 Starting version update process...${NC}"
echo "======================================"

# Update Go versions
echo -e "${YELLOW}🔄 Updating Go versions...${NC}"
./scripts/update_go_version.sh
if [ $? -ne 0 ]; then
  echo -e "${RED}❌ Go version update failed${NC}"
  exit 1
fi

# Update HAProxy versions
echo -e "${YELLOW}🔄 Updating HAProxy versions...${NC}"
./scripts/update_haproxy_version.sh
if [ $? -ne 0 ]; then
  echo -e "${RED}❌ HAProxy version update failed${NC}"
  exit 1
fi

# Update Docker Compose versions if needed
echo -e "${YELLOW}🔄 Updating Docker Compose references...${NC}"
# This is handled automatically through environment variables

# Verify all versions after update
echo -e "${YELLOW}🔍 Verifying version consistency...${NC}"
./scripts/verify_versions.sh
VERIFY_STATUS=$?

echo "======================================"
if [ $VERIFY_STATUS -eq 0 ]; then
  echo -e "${GREEN}✅ All versions have been successfully updated according to versions.mk${NC}"
else
  echo -e "${YELLOW}⚠️  Version update completed, but some inconsistencies remain.${NC}"
  echo "Please review the verification output and fix any remaining issues manually."
fi

echo -e "To see the current versions, run: ${GREEN}make versions${NC}"
echo -e "To see version details, run: ${GREEN}cat versions.mk${NC}"
