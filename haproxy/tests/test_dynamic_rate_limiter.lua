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
