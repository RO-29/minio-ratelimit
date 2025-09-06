# Bandwidth-Based Rate Limiting Implementation Plan

## Objective

Implement bandwidth-based rate limiting in the existing HAProxy setup to control the data transfer rate for PUT and GET requests, in addition to the current request-based rate limiting.

## Analysis of Existing System

The current system uses HAProxy and Lua to enforce rate limits based on the number of requests per minute and per second. The key components of the existing system are:

*   **HAProxy:** The core of the rate limiting solution.
*   **Lua Scripts:** `dynamic_rate_limiter.lua` and `extract_api_keys.lua` for request-based limiting and API key extraction.
*   **Stick Tables:** HAProxy stick tables are used to track request rates for each API key.
*   **Dynamic Configuration:** Rate limits are stored in `map` files, allowing for hot-reloading without restarting HAProxy.

## Proposed Plan

My plan to implement bandwidth-based rate limiting is as follows:

1.  **Update `haproxy.cfg` to Track Bandwidth:**
    *   Introduce two new stick tables to track incoming and outgoing data transfer rates.
    *   These tables will store `http_bytes_in_rate()` and `http_bytes_out_rate()` for each API key.
    *   Add rules to track the request body size (`req.body_size`) for `PUT` requests and the response body size (`res.body_size`) for `GET` requests.

2.  **Create New Dynamic Configuration `map` Files:**
    *   Create `haproxy/config/bandwidth_limit_in.map` to define incoming bandwidth limits (for `PUT` requests) for each group.
    *   Create `haproxy/config/bandwidth_limit_out.map` to define outgoing bandwidth limits (for `GET` requests) for each group.

3.  **Enhance the Lua Script (`dynamic_rate_limiter.lua`):**
    *   Add a new function to the Lua script called `check_bandwidth_limit`.
    *   This function will:
        *   Read the bandwidth limits from the new `.map` files.
        *   Fetch the current bandwidth usage from the new stick tables.
        *   Compare the usage against the limits.
        *   If a limit is exceeded, it will set a transaction variable (e.g., `txn.bandwidth_limit_exceeded`) and generate a corresponding error message.

4.  **Integrate the New Logic into the Request Flow:**
    *   In `haproxy.cfg`, after the existing rate-limiting checks, add a call to the new `check_bandwidth_limit` Lua function.
    *   Add a new `http-request deny` rule to block requests if the `txn.bandwidth_limit_exceeded` variable is set to `true`.

## Implementation Details

### 1. New `map` Files

I created the following two files:

*   `haproxy/config/bandwidth_limit_in.map`:

```
# Bandwidth limits for incoming data (PUT requests) in bytes per minute
# Example: 1073741824 = 1 GB/min
premium 1073741824
standard 536870912
basic 104857600
default 104857600
```

*   `haproxy/config/bandwidth_limit_out.map`:

```
# Bandwidth limits for outgoing data (GET requests) in bytes per minute
# Example: 2147483648 = 2 GB/min
premium 2147483648
standard 1073741824
basic 209715200
default 209715200
```

### 2. Modified `dynamic_rate_limiter.lua`

I added the `check_bandwidth_limit` function and registered it as a new action:

```lua
function check_bandwidth_limit(txn)
    -- Fast path: Check method first
    local method = txn.sf:method()
    if method ~= method_put and method ~= method_get then
        txn:set_var("txn.bandwidth_limit_exceeded", rate_not_exceeded)
        return -- Early exit
    end

    local api_key = txn:get_var("txn.api_key")
    if not api_key or api_key == "" then
        txn:set_var("txn.bandwidth_limit_exceeded", rate_not_exceeded)
        return -- Early exit
    end

    local current_bandwidth_rate
    local limit
    if method == method_put then
        current_bandwidth_rate = tonumber(txn.sf:sc_bytes_in_rate(2)) or 0
        limit = tonumber(txn:get_var("txn.bandwidth_limit_in")) or default_bandwidth_limit_in
    else -- method_get
        current_bandwidth_rate = tonumber(txn.sf:sc_bytes_out_rate(3)) or 0
        limit = tonumber(txn:get_var("txn.bandwidth_limit_out")) or default_bandwidth_limit_out
    end

    if current_bandwidth_rate > limit then
        local error_message = txn:get_var("txn.error_message") or default_error_msg
        local path = txn.sf:path()
        local uuid = txn.sf:uuid()

        local error_xml = string.format(error_template_bandwidth,
            error_message,
            limit,
            path,
            uuid,
            api_key
        )

        txn:set_var("txn.bandwidth_limit_exceeded", rate_exceeded)
        txn:set_var("txn.rate_limit_error", error_xml) -- Reuse the same error variable
        return
    end

    txn:set_var("txn.bandwidth_limit_exceeded", rate_not_exceeded)
end

-- Register the optimized functions
core.register_action("check_rate_limit", {"http-req"}, check_rate_limit, 0)
core.register_action("calc_remaining_requests", {"http-req"}, calc_remaining_requests, 0)
core.register_action("check_bandwidth_limit", {"http-req"}, check_bandwidth_limit, 0)
```

### 3. Modified `haproxy.cfg`

I updated the frontend and added new backends for the stick tables:

```haproxy
# Frontend for S3 API requests with OPTIMIZED rate limiting
frontend s3_frontend_optimized
    # ... (existing configuration)

    # Only load rate limits if we have an API key (performance optimization)
    http-request set-var(txn.rate_limit_per_minute) var(txn.rate_group),map(/usr/local/etc/haproxy/config/rate_limits_per_minute.map,50) if { var(txn.api_key) -m found }
    http-request set-var(txn.rate_limit_per_second) var(txn.rate_group),map(/usr/local/etc/haproxy/config/rate_limits_per_second.map,5) if { var(txn.api_key) -m found }
    http-request set-var(txn.error_message) var(txn.rate_group),map(/usr/local/etc/haproxy/config/error_messages.map,Rate_limit_exceeded) if { var(txn.api_key) -m found }
    http-request set-var(txn.bandwidth_limit_in) var(txn.rate_group),map(/usr/local/etc/haproxy/config/bandwidth_limit_in.map,104857600) if { var(txn.api_key) -m found }
    http-request set-var(txn.bandwidth_limit_out) var(txn.rate_group),map(/usr/local/etc/haproxy/config/bandwidth_limit_out.map,209715200) if { var(txn.api_key) -m found }

    # Only track API keys if we have a valid API key (performance optimization)
    http-request track-sc0 var(txn.api_key) table api_key_rates_1m if { method PUT GET }
    http-request track-sc1 var(txn.api_key) table api_key_rates_1s if { method PUT GET }
    http-request track-sc2 var(txn.api_key) table api_key_bandwidth_in if { method PUT }
    http-request track-sc3 var(txn.api_key) table api_key_bandwidth_out if { method GET }

    # Optimized rate limiting using Lua (only for PUT/GET)
    http-request lua.check_rate_limit if { method PUT GET }
    http-request lua.check_bandwidth_limit if { method PUT GET }

    # Deny request if rate limit exceeded (fast check)
    http-request deny deny_status 429 content-type "application/xml" lf-string "%[var(txn.rate_limit_error)]" if { var(txn.rate_limit_exceeded) -m str true }
    http-request deny deny_status 429 content-type "application/xml" lf-string "%[var(txn.rate_limit_error)]" if { var(txn.bandwidth_limit_exceeded) -m str true }

    # ... (rest of the configuration)

# ... (existing backends)

backend api_key_bandwidth_in
    stick-table type string len 32 size 50k expire 90s store bytes_in_rate(1m)

backend api_key_bandwidth_out
    stick-table type string len 32 size 50k expire 90s store bytes_out_rate(1m)
```

## Summary

The implementation of bandwidth-based rate limiting is now complete. The system now enforces both request-based and bandwidth-based rate limits, and the new limits can be managed dynamically through the new `map` files. To fully manage these new limits, the `manage-dynamic-limits` script should be updated to support the new `bandwidth_limit_in.map` and `bandwidth_limit_out.map` files.
