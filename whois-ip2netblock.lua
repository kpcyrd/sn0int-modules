-- Description: Lookup the netblock from an ip using whois
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: ipaddrs

function run(arg)
    local s = sock_connect('whois.arin.net', 43, {})
    if last_err() then return end

    sock_send(s, 'n + ' .. arg['value'] .. '\r\n')
    local x = sock_recvall(s)
    if last_err() then return end
    -- debug(x)

    local m = regex_find('CIDR:\\s+(.+)', x)
    if m then
        m = regex_find_all('[^\\s,]+', m[2])

        for i=1, #m do
            local netblock = m[i][1]
            db_add('netblock', {
                value=netblock,
            })
        end
    end
end
