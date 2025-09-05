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
