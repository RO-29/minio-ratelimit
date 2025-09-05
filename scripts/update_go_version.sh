#!/bin/bash
# Script to update go.mod file with the version from versions.mk

# Load the versions from versions.mk
source <(grep -E '^GO_VERSION|^GO_TOOLCHAIN_VERSION' ./versions.mk | sed 's/ := /=/g')

# If versions aren't set, use defaults
GO_VERSION=${GO_VERSION:-1.24}
GO_TOOLCHAIN_VERSION=${GO_TOOLCHAIN_VERSION:-1.24.5}

# Update go.mod files
update_go_mod() {
  local go_mod_file=$1

  if [ -f "$go_mod_file" ]; then
    echo "Updating $go_mod_file to Go version $GO_VERSION (toolchain $GO_TOOLCHAIN_VERSION)"

    # Update go directive
    sed -i '' "s/^go .*/go $GO_VERSION/" "$go_mod_file"

    # Update toolchain directive if it exists, otherwise add it
    if grep -q "^toolchain " "$go_mod_file"; then
      sed -i '' "s/^toolchain .*/toolchain go$GO_TOOLCHAIN_VERSION/" "$go_mod_file"
    else
      # Add after go directive
      sed -i '' "/^go /a\\
toolchain go$GO_TOOLCHAIN_VERSION
" "$go_mod_file"
    fi
  fi
}

# Update main go.mod file if it exists
update_go_mod "./go.mod"

# Update go.mod in cmd/ratelimit-test
update_go_mod "./cmd/ratelimit-test/go.mod"

echo "Go version updates complete."
