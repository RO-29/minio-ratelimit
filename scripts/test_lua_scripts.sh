#!/bin/sh
# Lua script test runner for HAProxy Lua scripts
# This runs simple syntax checks and unit tests for HAProxy Lua scripts

# Set colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Check if Lua is available
if ! command -v lua >/dev/null 2>&1; then
    echo "${YELLOW}Warning: Lua not found, using Docker if available${RESET}"
    USE_DOCKER=true
else
    USE_DOCKER=false
fi

# Directory containing Lua scripts
SCRIPT_DIR="./haproxy/lua"
TEST_DIR="./haproxy/tests"

# Create test directory if it doesn't exist
mkdir -p "$TEST_DIR"

# Generate simple test wrapper for extract_api_keys.lua
cat > "$TEST_DIR/test_extract_api_keys.lua" << 'EOF'
-- Test wrapper for extract_api_keys.lua
package.path = package.path .. ";../lua/?.lua"

-- Mock HAProxy functions
core = {}
core.log = function(level, msg) print("[LOG] " .. msg) end
core.Debug = 0
core.Info = 1
core.Warning = 2
core.Error = 3

-- Load the script
dofile("../lua/extract_api_keys.lua")

-- Test cases
function test_extract_aws_key()
    local test_cases = {
        {
            name = "Valid AWS4 credential",
            input = "AWS4-HMAC-SHA256 Credential=TEST123KEY/20250904/us-east-1/s3/aws4_request",
            expected = "TEST123KEY"
        },
        {
            name = "Empty string",
            input = "",
            expected = ""
        }
    }

    local pass = 0
    local total = #test_cases

    for _, test in ipairs(test_cases) do
        print("Running test: " .. test.name)
        local result = extract_aws_key(test.input)
        if result == test.expected then
            print(string.format("✅ PASS: Expected '%s', got '%s'", test.expected, result))
            pass = pass + 1
        else
            print(string.format("❌ FAIL: Expected '%s', got '%s'", test.expected, result))
        end
    end

    print(string.format("\nPassed %d/%d tests", pass, total))
    return pass == total
end

-- Run tests
local success = test_extract_aws_key()
if success then
    os.exit(0)
else
    os.exit(1)
end
EOF

# Generate simple test wrapper for dynamic_rate_limiter.lua
cat > "$TEST_DIR/test_dynamic_rate_limiter.lua" << 'EOF'
-- Test wrapper for dynamic_rate_limiter.lua
package.path = package.path .. ";../lua/?.lua"

-- Mock HAProxy functions
core = {}
core.log = function(level, msg) print("[LOG] " .. msg) end
core.register_action = function() end
core.tcp = function() end
core.Debug = 0
core.Info = 1
core.Warning = 2
core.Error = 3

-- Load the script
dofile("../lua/dynamic_rate_limiter.lua")

-- Test cases
function test_basic_functions()
    local test_cases = {
        {
            name = "Test function existence",
            test = function()
                return type(dynamic_rate_limit) == "function"
            end
        }
    }

    local pass = 0
    local total = #test_cases

    for _, test in ipairs(test_cases) do
        print("Running test: " .. test.name)
        local result = test.test()
        if result then
            print("✅ PASS")
            pass = pass + 1
        else
            print("❌ FAIL")
        end
    end

    print(string.format("\nPassed %d/%d tests", pass, total))
    return pass == total
end

-- Run tests
local success = test_basic_functions()
if success then
    os.exit(0)
else
    os.exit(1)
end
EOF

# Run tests
echo "${BLUE}Running Lua script tests...${RESET}"

if [ "$USE_DOCKER" = true ]; then
    if command -v docker >/dev/null 2>&1; then
        # Run tests in Docker
        echo "${YELLOW}Using Docker to run Lua tests${RESET}"
        docker run --rm -v "$(pwd)/haproxy:/haproxy" alpine:latest sh -c "
            apk add --no-cache lua5.3
            cd /haproxy/tests
            lua test_extract_api_keys.lua && lua test_dynamic_rate_limiter.lua
        "
        result=$?
    else
        echo "${RED}Error: Neither Lua nor Docker is available${RESET}"
        exit 1
    fi
else
    # Run tests locally
    (cd "$TEST_DIR" && lua test_extract_api_keys.lua && lua test_dynamic_rate_limiter.lua)
    result=$?
fi

# Report results
if [ $result -eq 0 ]; then
    echo "${GREEN}✅ All Lua tests passed!${RESET}"
    exit 0
else
    echo "${RED}❌ Some Lua tests failed!${RESET}"
    exit 1
fi
