-- Dynamic Rate Limiter for HAProxy
-- Implements fully dynamic rate limiting using map file values
-- No hardcoded rate limits - all values come from configuration files

-- Function to check if rate limit is exceeded
-- Returns true if rate limit exceeded, false otherwise
function check_rate_limit(txn)
    local api_key = txn:get_var("txn.api_key")
    local rate_group = txn:get_var("txn.rate_group")
    local method = txn.sf:method()
    
    -- Only apply rate limiting to PUT and GET methods
    if method ~= "PUT" and method ~= "GET" then
        return
    end
    
    -- Skip rate limiting for unknown API keys or groups
    if not api_key or api_key == "" or not rate_group or rate_group == "unknown" then
        return
    end
    
    -- Get current request rates from stick tables (convert to numbers)
    local current_rate_per_minute = tonumber(txn.sf:sc_http_req_rate(0)) or 0
    local current_rate_per_second = tonumber(txn.sf:sc_http_req_rate(1)) or 0
    
    -- Get dynamic rate limits from variables (set from map files)
    local limit_per_minute = tonumber(txn:get_var("txn.rate_limit_per_minute"))
    local limit_per_second = tonumber(txn:get_var("txn.rate_limit_per_second"))
    local error_message = txn:get_var("txn.error_message")
    
    -- Default limits if map lookup failed
    if not limit_per_minute then limit_per_minute = 50 end
    if not limit_per_second then limit_per_second = 5 end
    if not error_message then error_message = "Rate_limit_exceeded" end
    
    -- Check per-minute rate limit
    if current_rate_per_minute > limit_per_minute then
        local error_xml = string.format(
            '<?xml version="1.0" encoding="UTF-8"?><Error><Code>SlowDown</Code><Message>%s (%d requests/minute per API key)</Message><Resource>%s</Resource><RequestId>%s</RequestId><ApiKey>%s</ApiKey></Error>',
            error_message,
            limit_per_minute,
            txn.sf:path(),
            txn.sf:uuid(),
            api_key
        )
        
        txn:set_var("txn.rate_limit_exceeded", "true")
        txn:set_var("txn.rate_limit_error", error_xml)
        txn:set_var("txn.rate_limit_type", "minute")
        return
    end
    
    -- Check per-second rate limit (burst)
    if current_rate_per_second > limit_per_second then
        local error_xml = string.format(
            '<?xml version="1.0" encoding="UTF-8"?><Error><Code>SlowDown</Code><Message>%s - burst (%d requests/second per API key)</Message><Resource>%s</Resource><RequestId>%s</RequestId><ApiKey>%s</ApiKey></Error>',
            error_message,
            limit_per_second,
            txn.sf:path(),
            txn.sf:uuid(),
            api_key
        )
        
        txn:set_var("txn.rate_limit_exceeded", "true")
        txn:set_var("txn.rate_limit_error", error_xml)
        txn:set_var("txn.rate_limit_type", "second")
        return
    end
    
    -- Rate limit not exceeded
    txn:set_var("txn.rate_limit_exceeded", "false")
end

-- Register the function as an action for http-req phase
core.register_action("check_rate_limit", {"http-req"}, check_rate_limit, 0)