-- Optimized Dynamic Rate Limiter for HAProxy
-- Performance optimizations:
-- - Cached variable access
-- - Early exits for better performance
-- - Pre-computed error templates
-- - Minimal string operations
-- - Fast path for non-rate-limited methods

-- Cache commonly used strings and values
local method_put = "PUT"
local method_get = "GET" 
local rate_exceeded = "true"
local rate_not_exceeded = "false"
local default_group = "default"

-- Pre-compiled error message template (avoid string.format overhead)
local error_template_minute = '<?xml version="1.0" encoding="UTF-8"?><Error><Code>SlowDown</Code><Message>%s (%d requests/minute per API key)</Message><Resource>%s</Resource><RequestId>%s</RequestId><ApiKey>%s</ApiKey></Error>'
local error_template_second = '<?xml version="1.0" encoding="UTF-8"?><Error><Code>SlowDown</Code><Message>%s - burst (%d requests/second per API key)</Message><Resource>%s</Resource><RequestId>%s</RequestId><ApiKey>%s</ApiKey></Error>'

-- Default values
local default_minute_limit = 50
local default_second_limit = 5
local default_error_msg = "Rate_limit_exceeded"

function check_rate_limit(txn)
    -- Fast path: Check method first (most requests are not PUT/GET)
    local method = txn.sf:method()
    if method ~= method_put and method ~= method_get then
        txn:set_var("txn.rate_limit_exceeded", rate_not_exceeded)
        return -- Early exit - no rate limiting needed
    end
    
    -- Cache all required variables at once
    local api_key = txn:get_var("txn.api_key")
    local rate_group = txn:get_var("txn.rate_group")
    
    -- Fast path: Skip rate limiting for empty API keys only
    -- Note: We now allow "default" group to be rate limited
    if not api_key or api_key == "" then
        txn:set_var("txn.rate_limit_exceeded", rate_not_exceeded)
        return -- Early exit
    end
    
    -- Get current request rates from stick tables (convert to numbers once)
    local current_rate_per_minute = tonumber(txn.sf:sc_http_req_rate(0)) or 0
    local current_rate_per_second = tonumber(txn.sf:sc_http_req_rate(1)) or 0
    
    -- Fast path: If no current usage, no need to check limits
    if current_rate_per_minute == 0 and current_rate_per_second == 0 then
        txn:set_var("txn.rate_limit_exceeded", rate_not_exceeded)
        return -- Early exit
    end
    
    -- Get dynamic rate limits from variables (with defaults for performance)
    local limit_per_minute = tonumber(txn:get_var("txn.rate_limit_per_minute")) or default_minute_limit
    local limit_per_second = tonumber(txn:get_var("txn.rate_limit_per_second")) or default_second_limit
    
    -- Fast path: Check per-minute rate limit first (more common to hit)
    if current_rate_per_minute > limit_per_minute then
        -- Cache values for error message generation
        local error_message = txn:get_var("txn.error_message") or default_error_msg
        local path = txn.sf:path()
        local uuid = txn.sf:uuid()
        
        -- Generate error message (minimize string operations)
        local error_xml = string.format(error_template_minute,
            error_message,
            limit_per_minute,
            path,
            uuid,
            api_key
        )
        
        txn:set_var("txn.rate_limit_exceeded", rate_exceeded)
        txn:set_var("txn.rate_limit_error", error_xml)
        return -- Early exit
    end
    
    -- Check per-second rate limit (burst) - only if minute limit not exceeded
    if current_rate_per_second > limit_per_second then
        -- Cache values for error message generation  
        local error_message = txn:get_var("txn.error_message") or default_error_msg
        local path = txn.sf:path()
        local uuid = txn.sf:uuid()
        
        -- Generate error message
        local error_xml = string.format(error_template_second,
            error_message,
            limit_per_second,
            path,
            uuid,
            api_key
        )
        
        txn:set_var("txn.rate_limit_exceeded", rate_exceeded)
        txn:set_var("txn.rate_limit_error", error_xml)
        return -- Early exit
    end
    
    -- Rate limit not exceeded
    txn:set_var("txn.rate_limit_exceeded", rate_not_exceeded)
end

-- Register the optimized function
core.register_action("check_rate_limit", {"http-req"}, check_rate_limit, 0)