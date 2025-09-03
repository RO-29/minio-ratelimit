-- HAProxy Lua script to extract API keys from all S3 authentication methods
-- This script handles V2, V4, pre-signed URLs, and custom headers

function extract_api_key(txn)
    -- Get the Authorization header
    local auth_header = txn.http:req_get_headers()["authorization"]
    local api_key = nil
    local auth_method = nil
    
    if auth_header then
        local auth = auth_header[0]  -- Get first value if multiple
        if auth then
            core.Debug("Processing auth header: " .. auth)
            
            -- Method 1: AWS Signature V4
            if string.match(auth, "^AWS4%-HMAC%-SHA256") then
                local credential_part = string.match(auth, "Credential=([^,]+)")
                if credential_part then
                    api_key = string.match(credential_part, "([^/]+)")
                    if api_key then
                        auth_method = "v4_header_lua"
                        core.Debug("Extracted V4 API key: " .. api_key)
                    end
                end
            
            -- Method 2: AWS Signature V2 
            elseif string.match(auth, "^AWS [^:]+:") then
                -- Format: AWS AKIAIOSFODNN7EXAMPLE:signature
                api_key = string.match(auth, "^AWS ([^:]+):")
                if api_key then
                    auth_method = "v2_header_lua"
                    core.Debug("Extracted V2 API key: " .. api_key)
                end
            end
        end
    end
    
    -- Method 3: Pre-signed URL with X-Amz-Credential
    if not api_key then
        local query_string = txn.f:query()
        if query_string then
            local cred_match = string.match(query_string, "X%-Amz%-Credential=([^&]+)")
            if cred_match then
                -- URL decode if needed
                cred_match = string.gsub(cred_match, "%%2F", "/")
                api_key = string.match(cred_match, "([^/]+)")
                if api_key then
                    auth_method = "v4_presigned_lua"
                    core.Debug("Extracted presigned API key: " .. api_key)
                end
            end
        end
    end
    
    -- Method 4: Legacy query parameter AWSAccessKeyId
    if not api_key then
        local query_string = txn.f:query()
        if query_string then
            api_key = string.match(query_string, "AWSAccessKeyId=([^&]+)")
            if api_key then
                auth_method = "v2_query_lua"
                core.Debug("Extracted query API key: " .. api_key)
            end
        end
    end
    
    -- Method 5: Custom headers
    if not api_key then
        local headers = txn.http:req_get_headers()
        if headers["x-api-key"] then
            api_key = headers["x-api-key"][0]
            auth_method = "custom_lua"
        elseif headers["x-access-key-id"] then
            api_key = headers["x-access-key-id"][0] 
            auth_method = "custom_lua"
        end
        if api_key then
            core.Debug("Extracted custom header API key: " .. api_key)
        end
    end
    
    -- Set variables
    if api_key then
        txn:set_var("txn.api_key", api_key)
        txn:set_var("txn.auth_method", auth_method)
    else
        -- Default for unknown keys
        txn:set_var("txn.api_key", "unknown")
        txn:set_var("txn.auth_method", "none")
    end
    
    return api_key
end

-- Register the function to be called by HAProxy
core.register_action("extract_api_key", {"http-req"}, extract_api_key, 0)