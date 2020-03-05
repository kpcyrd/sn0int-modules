-- Description: Send an http request and update our cached response
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: urls

function run(arg)
    local session = http_mksession()
    local req = http_request(session, 'GET', arg['value'], {
        timeout=5000,
        binary=true,
    })
    local r = http_send(req)
    if last_err() then return end

    db_update('url', arg, {
        status=r['status'],
        body=r['binary'],
        redirect=r['headers']['location'],
    })
end
