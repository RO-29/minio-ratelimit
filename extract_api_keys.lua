-- Optimized S3 API Key Extraction for HAProxy 3.0
-- Performance optimizations:
-- - Pre-compiled patterns (stored as locals)
-- - Minimal string operations
-- - Early exits for performance
-- - Cached header access
-- - Optimized variable setting

-- Pre-compile regex patterns for better performance
local v4_pattern = "^AWS4%-HMAC%-SHA256"
local v2_pattern = "^AWS "
local credential_pattern = "Credential=([^,]+)"
local key_pattern = "([^/]+)"
local presigned_pattern = "X%-Amz%-Credential=([^&]+)"
local access_key_pattern = "AWSAccessKeyId=([^&]+)"

-- Cache commonly used strings
local v4_method = "v4_header_lua"
local v2_method = "v2_header_lua"
local v4_presigned_method = "v4_presigned_lua"
local v2_query_method = "v2_query_lua"
local custom_method = "custom_lua"

function extract_api_key(txn)
    -- Cache transaction variables for better performance
    local headers = txn.http:req_get_headers()
    local auth_header = headers["authorization"]
    
    -- Fast path: Check for most common authentication method first (V4 header)
    if auth_header and auth_header[0] then
        local auth = auth_header[0]
        
        -- AWS Signature V4 (most common in modern apps)
        if string.find(auth, v4_pattern) then
            local credential_part = string.match(auth, credential_pattern)
            if credential_part then
                local api_key = string.match(credential_part, key_pattern)
                if api_key then
                    txn:set_var("txn.api_key", api_key)
                    txn:set_var("txn.auth_method", v4_method)
                    return -- Early exit for performance
                end
            end
        end
        
        -- AWS Signature V2 (legacy but still used)
        if string.find(auth, v2_pattern) then
            local api_key = string.match(auth, "AWS ([^:]+):")
            if api_key then
                txn:set_var("txn.api_key", api_key)
                txn:set_var("txn.auth_method", v2_method)
                return -- Early exit
            end
        end
    end
    
    -- Check query string for pre-signed URLs (less common, check after headers)
    local query_string = txn.f:query()
    if query_string then
        -- V4 pre-signed URL
        local credential_match = string.match(query_string, presigned_pattern)
        if credential_match then
            local api_key = string.match(credential_match, key_pattern)
            if api_key then
                txn:set_var("txn.api_key", api_key)
                txn:set_var("txn.auth_method", v4_presigned_method)
                return -- Early exit
            end
        end
        
        -- V2 query parameter (legacy)
        local api_key = string.match(query_string, access_key_pattern)
        if api_key then
            txn:set_var("txn.api_key", api_key)
            txn:set_var("txn.auth_method", v2_query_method)
            return -- Early exit
        end
    end
    
    -- Check custom headers (least common, check last)
    local custom_headers = {"x-api-key", "x-access-key-id", "x-amz-security-token"}
    for _, header_name in ipairs(custom_headers) do
        local header_value = headers[header_name]
        if header_value and header_value[0] then
            local api_key = header_value[0]
            if api_key and #api_key > 0 then
                txn:set_var("txn.api_key", api_key)
                txn:set_var("txn.auth_method", custom_method)
                return -- Early exit
            end
        end
    end
    
    -- No API key found - set empty values
    txn:set_var("txn.api_key", "")
    txn:set_var("txn.auth_method", "none")
end

-- Register the optimized function
core.register_action("extract_api_key", {"http-req"}, extract_api_key, 0)