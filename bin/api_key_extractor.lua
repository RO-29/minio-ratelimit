-- API Key Extraction Lua Script for HAProxy
-- Handles AWS Signature V4 and V2 authentication methods

-- Configuration for API key groups (can be hot-reloaded)
local api_key_config = {}
local config_file = "/etc/haproxy/api_keys.json" 
local last_config_mtime = 0

-- Load API key configuration from file
function load_api_key_config()
    local file = io.open(config_file, "r")
    if not file then
        core.log(core.warning, "API key config file not found: " .. config_file)
        return
    end
    
    local content = file:read("*all")
    file:close()
    
    -- Simple JSON parsing for our configuration
    -- In production, consider using a proper JSON library
    local success, config = pcall(function()
        -- Remove whitespace and parse basic structure
        content = content:gsub("%s+", "")
        local keys = {}
        
        -- Extract API keys and their groups
        for key, group in content:gmatch('"([^"]+)"%s*:%s*"([^"]+)"') do
            keys[key] = group
        end
        
        return keys
    end)
    
    if success then
        api_key_config = config
        core.log(core.info, "Loaded " .. table_size(api_key_config) .. " API keys")
    else
        core.log(core.err, "Failed to parse API key config: " .. config_file)
    end
end

-- Helper function to get table size
function table_size(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- Extract API key from AWS Authorization header
function extract_api_key(txn)
    local api_key = nil
    
    -- Method 1: AWS Signature V4 from Authorization header
    -- Format: AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request...
    local auth_header = txn.sf:req_hdr("Authorization")
    if auth_header then
        -- AWS Signature V4
        local v4_key = auth_header:match("AWS4%-HMAC%-SHA256%s+Credential=([^/]+)/")
        if v4_key then
            api_key = v4_key
            txn:set_var("txn.auth_method", "v4")
        else
            -- AWS Signature V2  
            -- Format: AWS AKIAIOSFODNN7EXAMPLE:frJIUN8DYpKDtOLCwo//yllqDzg=
            local v2_key = auth_header:match("AWS%s+([^:]+):")
            if v2_key then
                api_key = v2_key
                txn:set_var("txn.auth_method", "v2")
            end
        end
    end
    
    -- Method 2: Query parameters (pre-signed URLs)
    if not api_key then
        -- AWS Signature V4 query params
        -- ?X-Amz-Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request
        local query_string = txn.sf:query()
        if query_string then
            local v4_key = query_string:match("X%-Amz%-Credential=([^/&]+)")
            if v4_key then
                api_key = v4_key
                txn:set_var("txn.auth_method", "v4_query")
            else
                -- AWS Signature V2 query params
                -- ?AWSAccessKeyId=AKIAIOSFODNN7EXAMPLE
                local v2_key = query_string:match("AWSAccessKeyId=([^&]+)")
                if v2_key then
                    api_key = v2_key
                    txn:set_var("txn.auth_method", "v2_query")
                end
            end
        end
    end
    
    -- Method 3: Custom headers (fallback)
    if not api_key then
        api_key = txn.sf:req_hdr("X-API-Key") or txn.sf:req_hdr("X-Access-Key-Id")
        if api_key then
            txn:set_var("txn.auth_method", "custom")
        end
    end
    
    -- Set default if no key found
    if not api_key then
        api_key = "unknown"
        txn:set_var("txn.auth_method", "none")
    end
    
    -- Store the extracted API key
    txn:set_var("txn.api_key", api_key)
    
    -- Log for debugging
    core.log(core.info, "Extracted API key: " .. api_key .. " (method: " .. (txn:get_var("txn.auth_method") or "unknown") .. ")")
end

-- Get rate limit group for API key
function get_rate_group(txn)
    -- Reload config if file has been modified
    check_and_reload_config()
    
    local api_key = txn:get_var("txn.api_key")
    if not api_key then
        txn:set_var("txn.rate_group", "unknown")
        return
    end
    
    -- Look up the API key in configuration
    local group = api_key_config[api_key] or "basic"
    txn:set_var("txn.rate_group", group)
    
    core.log(core.info, "API key " .. api_key .. " assigned to group: " .. group)
end

-- Check if config file has been modified and reload if needed
function check_and_reload_config()
    -- Simple file modification check
    -- In production, consider using inotify or similar
    local file = io.open(config_file, "r")
    if file then
        local attrs = file:read(0) -- Just check if readable
        file:close()
        
        -- For simplicity, reload periodically
        local current_time = os.time()
        if current_time - last_config_mtime > 30 then -- Check every 30 seconds
            load_api_key_config()
            last_config_mtime = current_time
        end
    end
end

-- Calculate remaining requests for rate limiting
function calculate_remaining(txn)
    local rate_group = txn:get_var("txn.rate_group") or "basic"
    local current_rate = txn:get_var("txn.current_rate_1m") or 0
    
    -- Group-based limits
    local limits = {
        premium = 1000,
        standard = 500,
        basic = 100,
        unknown = 50
    }
    
    local limit = limits[rate_group] or limits["basic"]
    local remaining = math.max(0, limit - current_rate)
    
    txn:set_var("txn.remaining_requests", remaining)
    
    core.log(core.debug, "Rate calculation - Group: " .. rate_group .. 
             ", Limit: " .. limit .. ", Current: " .. current_rate .. ", Remaining: " .. remaining)
end

-- Initialize configuration on startup
load_api_key_config()

-- Register functions with HAProxy
core.register_action("extract_api_key", {"http-req"}, extract_api_key, 0)
core.register_action("get_rate_group", {"http-req"}, get_rate_group, 0) 
core.register_action("calculate_remaining", {"http-req"}, calculate_remaining, 0)