-- API Key Extractor for S3 Requests
-- Supports both AWS Signature V4 and V2

local api_key_groups = {}

-- Load API key groups configuration
function load_api_key_groups()
    local file = io.open("/etc/haproxy/api_key_groups.conf", "r")
    if not file then
        core.log(core.warning, "Could not load API key groups configuration")
        return
    end
    
    api_key_groups = {}
    for line in file:lines() do
        if line:match("^%s*#") or line:match("^%s*$") then
            -- Skip comments and empty lines
        else
            local key, group = line:match("^([^:]+):([^:]+)$")
            if key and group then
                api_key_groups[key] = group:gsub("%s+", "")
                core.log(core.info, "Loaded API key: " .. key .. " -> group: " .. group)
            end
        end
    end
    file:close()
end

-- Initialize API key groups on startup
load_api_key_groups()

-- Extract API key from various S3 authentication methods
function extract_api_key(txn)
    local api_key = nil
    
    -- Method 1: Authorization header (AWS4-HMAC-SHA256)
    local auth_header = txn.http:req_get_headers()["authorization"]
    if auth_header and auth_header[0] then
        local auth = auth_header[0]
        
        -- AWS Signature V4
        local v4_key = auth:match("AWS4%-HMAC%-SHA256%s+Credential=([^/]+)/")
        if v4_key then
            api_key = v4_key
            core.log(core.info, "Extracted API key from AWS4 auth: " .. api_key)
        else
            -- AWS Signature V2
            local v2_key = auth:match("AWS%s+([^:]+):")
            if v2_key then
                api_key = v2_key
                core.log(core.info, "Extracted API key from AWS2 auth: " .. api_key)
            end
        end
    end
    
    -- Method 2: Query parameters
    if not api_key then
        local query = txn.http:req_get_query()
        if query then
            -- AWS Signature V4 query auth
            api_key = query:match("[?&]X%-Amz%-Credential=([^/&]+)/")
            if api_key then
                core.log(core.info, "Extracted API key from V4 query: " .. api_key)
            else
                -- AWS Signature V2 query auth
                api_key = query:match("[?&]AWSAccessKeyId=([^&]+)")
                if api_key then
                    core.log(core.info, "Extracted API key from V2 query: " .. api_key)
                end
            end
        end
    end
    
    -- Method 3: x-amz-security-token (for STS tokens)
    if not api_key then
        local token_header = txn.http:req_get_headers()["x-amz-security-token"]
        if token_header and token_header[0] then
            -- For STS tokens, we might want to extract from a different field
            -- This is a placeholder for custom STS handling
            core.log(core.info, "STS token detected, using default handling")
        end
    end
    
    -- Set default if no key found
    if not api_key then
        api_key = "anonymous"
        core.log(core.warning, "No API key found, using anonymous")
    end
    
    -- Store the API key in transaction variable
    txn:set_var("txn.api_key", api_key)
    
    return api_key
end

-- Get rate limiting group for API key
function get_rate_group(txn)
    local api_key = txn:get_var("txn.api_key")
    if not api_key then
        api_key = "anonymous"
    end
    
    -- Reload groups configuration if it has been updated
    local file_stat = core.stat("/etc/haproxy/api_key_groups.conf")
    if file_stat then
        load_api_key_groups()
    end
    
    local group = api_key_groups[api_key] or "basic"
    
    core.log(core.info, "API key: " .. api_key .. " -> group: " .. group)
    txn:set_var("txn.rate_group", group)
    
    return group
end

-- Calculate remaining requests for rate limiting
function calculate_remaining(txn)
    local rate_limit = tonumber(txn:get_var("txn.rate_limit_per_min")) or 0
    local current_rate = tonumber(txn:get_var("txn.current_rate_1m")) or 0
    local remaining = math.max(0, rate_limit - current_rate)
    
    txn:set_var("txn.remaining_requests", tostring(remaining))
    return tostring(remaining)
end

-- Enhanced logging function
function log_rate_limit_info(txn)
    local api_key = txn:get_var("txn.api_key") or "unknown"
    local group = txn:get_var("txn.rate_group") or "unknown"
    local current_rate = txn:get_var("txn.current_rate_1m") or "0"
    local limit = txn:get_var("txn.rate_limit_per_min") or "0"
    
    core.log(core.info, string.format("Rate limit check: key=%s, group=%s, current=%s, limit=%s", 
        api_key, group, current_rate, limit))
end

-- Register Lua functions
core.register_action("extract_api_key", {"http-req"}, extract_api_key)
core.register_fetches("get_rate_group", get_rate_group)
core.register_fetches("calculate_remaining", calculate_remaining)
core.register_action("log_rate_limit_info", {"http-req"}, log_rate_limit_info)