#!/bin/bash
# Master script to update all versions in the project

# Update Go versions
echo "Updating Go versions..."
./scripts/update_go_version.sh

# Update HAProxy versions
echo "Updating HAProxy versions..."
./scripts/update_haproxy_version.sh

# Update Docker Compose versions if needed
# This is handled automatically through environment variables

echo "All versions have been updated according to versions.mk"
echo "To see the current versions, run: make versions"
