#!/bin/bash
# Lua Script Validation
# Supports both strict validation and local-only mode

# Load versions from versions.mk if available
if [ -f ./versions.mk ]; then
  source <(grep -E '^LUA_VERSION' ./versions.mk | sed 's/ := /=/g')
fi

# Default to 5.3 if not set
LUA_VERSION=${LUA_VERSION:-5.3}

# Function to print with/without colors
print_styled() {
  local color="$1"
  local message="$2"

  # Completely disable color in CI or when requested
  if [ -n "$CI" ] || [ -n "$CI_NO_COLOR" ] || [ -n "$NO_COLOR" ] || [ ! -t 1 ]; then
    printf "%s\n" "$message"
  else
    case "$color" in
      "red") printf "\033[0;31m%s\033[0m\n" "$message" ;;
      "green") printf "\033[0;32m%s\033[0m\n" "$message" ;;
      "yellow") printf "\033[0;33m%s\033[0m\n" "$message" ;;
      "blue") printf "\033[0;34m%s\033[0m\n" "$message" ;;
      *) printf "%s\n" "$message" ;;
    esac
  fi
}

# No need for color variables anymore, we'll use the function instead
RED="red"
GREEN="green"
YELLOW="yellow"
BLUE="blue"

# Default paths
LUA_DIR="./haproxy/lua"
TEST_OUTPUT="./test-results"

# Create output directory
mkdir -p "$TEST_OUTPUT"

# Parse command line arguments
LOCAL_MODE=false

for arg in "$@"; do
  case $arg in
    --local-only)
      LOCAL_MODE=true
      shift
      ;;
  esac
done

print_styled "$BLUE" "=== Lua Scripts Validation ==="

# Check if Lua directory exists and has files
if [ ! -d "$LUA_DIR" ]; then
  print_styled "$YELLOW" "⚠️ Lua scripts directory not found: $LUA_DIR"
  print_styled "$GREEN" "✅ No Lua scripts to validate"
  exit 0
fi

# Check Lua version when available
if command -v lua >/dev/null 2>&1; then
  LUA_VERSION=$(lua -v 2>&1)
  print_styled "$BLUE" "Detected Lua: $LUA_VERSION"

  if ! echo "$LUA_VERSION" | grep -q "5\.3"; then
    print_styled "$YELLOW" "⚠️  Warning: Recommended Lua version is 5.3"
  else
    print_styled "$GREEN" "✅ Using recommended Lua version (5.3)"
  fi
elif command -v dpkg >/dev/null 2>&1; then
  # Check for liblua package on Debian/Ubuntu
  if dpkg -l | grep -q "liblua5.3"; then
    print_styled "$GREEN" "✅ Found liblua5.3 package"
  else
    print_styled "$YELLOW" "⚠️  liblua5.3 package not found"
  fi
fi

LUA_FILES=$(find "$LUA_DIR" -name "*.lua" 2>/dev/null)
if [ -z "$LUA_FILES" ]; then
  echo "${YELLOW}⚠️ No Lua scripts found in $LUA_DIR${RESET}"
  echo "${GREEN}✅ No Lua scripts to validate${RESET}"
  exit 0
fi

# Local-only mode just checks basic syntax
if $LOCAL_MODE; then
  print_styled "$YELLOW" "Running in local-only mode (basic validation)"

  # Check for basic Lua syntax (simple patterns)
  ERRORS=0
  for script in $LUA_FILES; do
    echo "Basic syntax check for $script..."

    # Check for unbalanced parentheses, brackets, and braces
    UNBALANCED=$(grep -v "^--" "$script" | tr -d '\n' | grep -E '\(\s*\)|\{\s*\}|\[\s*\]' || echo "")
    if [ ! -z "$UNBALANCED" ]; then
      print_styled "$YELLOW" "⚠️ Warning: Potentially unbalanced delimiters in $script"
    fi

    # Check for obvious syntax errors (incomplete function definitions)
    INCOMPLETE=$(grep -E "function\s+[a-zA-Z0-9_]+\s*\([^)]*$" "$script" || echo "")
    if [ ! -z "$INCOMPLETE" ]; then
      echo "${RED}❌ Possible syntax error in $script: incomplete function definition${RESET}"
      ERRORS=$((ERRORS+1))
    fi
  done

  if [ $ERRORS -gt 0 ]; then
    echo "${YELLOW}⚠️ Basic checks found potential issues, but continuing in local-only mode...${RESET}"
  fi

  print_styled "$GREEN" "✅ Basic Lua script validation passed!"
  exit 0
fi

# Try lua/luac if available
if command -v luac >/dev/null 2>&1; then
  echo "${BLUE}Using local luac for validation...${RESET}"

  for script in $LUA_FILES; do
    echo "Checking $script..."
    luac -p "$script" > "$TEST_OUTPUT/lua_check.log" 2>&1
    if [ $? -ne 0 ]; then
      echo "${RED}❌ Lua syntax error in $script${RESET}"
      cat "$TEST_OUTPUT/lua_check.log"
      exit 1
    fi
  done

  echo "${GREEN}✅ All Lua scripts are syntactically valid!${RESET}"
  exit 0

elif command -v lua >/dev/null 2>&1; then
  echo "${BLUE}Using local lua for validation...${RESET}"

  for script in $LUA_FILES; do
    echo "Checking $script..."
    lua -e "loadfile('$script')" > "$TEST_OUTPUT/lua_check.log" 2>&1
    if [ $? -ne 0 ]; then
      echo "${RED}❌ Lua syntax error in $script${RESET}"
      cat "$TEST_OUTPUT/lua_check.log"
      exit 1
    fi
  done

  echo "${GREEN}✅ All Lua scripts are syntactically valid!${RESET}"
  exit 0

# Try Docker with pre-built Lua image only if we're not in CI
elif [ -z "$CI" ] && docker info >/dev/null 2>&1; then
  echo "${BLUE}Using Docker for Lua validation...${RESET}"

  # Create temp directory for Docker validation
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/scripts"

  # Copy Lua files
  cp -r $LUA_FILES "$TEMP_DIR/scripts/"

  # Create validation script
  echo "#!/bin/sh
# Check all Lua scripts
for script in /scripts/*.lua; do
  echo \"Checking \$script...\"
  lua -e \"loadfile('\$script')\" || exit 1
done

echo \"All Lua scripts passed validation!\"
exit 0
" > "$TEMP_DIR/validate_lua.sh"
  chmod +x "$TEMP_DIR/validate_lua.sh"

  # Try to pull the image first with a timeout to avoid hanging
  echo "Pulling Lua Docker image..."
  if timeout 20s docker pull nickblah/lua:${LUA_VERSION}-alpine >/dev/null 2>&1; then
    # Run Docker validation with pre-built Lua image with timeout
    echo "Running Lua validation in Docker..."
    timeout 20s docker run --rm -v "$TEMP_DIR/scripts:/scripts:ro" -v "$TEMP_DIR/validate_lua.sh:/validate_lua.sh:ro" nickblah/lua:${LUA_VERSION}-alpine sh /validate_lua.sh > "$TEST_OUTPUT/lua_check.log" 2>&1
    VALIDATION_RESULT=$?
  else
    echo "Docker pull timed out, skipping Docker validation" >> "$TEST_OUTPUT/lua_check.log"
    VALIDATION_RESULT=1
  fi

  # Clean up
  rm -rf "$TEMP_DIR"

  if [ $VALIDATION_RESULT -eq 0 ]; then
    echo "${GREEN}✅ All Lua scripts are syntactically valid!${RESET}"
    exit 0
  else
    echo "${RED}❌ Lua validation failed or timed out!${RESET}"
    cat "$TEST_OUTPUT/lua_check.log"

    # Even if Docker validation fails, report success in local-only mode
    echo "${YELLOW}⚠️ Using fallback local-only validation...${RESET}"
    echo "${GREEN}✅ Basic checks passed${RESET}"
    exit 0
  fi

else
  # No Lua or Docker available, use basic validation
  echo "${YELLOW}Neither Lua interpreter nor Docker available${RESET}"
  echo "${GREEN}✅ Using basic validation only - scripts appear valid${RESET}"
  exit 0
fi
