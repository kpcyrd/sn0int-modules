-- Description: Collect information about stackoverflow users
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: accounts:stackoverflow.com

function run(arg)
    local session = http_mksession()

    local url = 'https://stackoverflow.com/users/' .. arg['username']

    local r = nil
    while true do
        debug(url)
        local req = http_request(session, 'GET', url, {})
        r = http_send(req)
        if last_err() then return end

        if r['status'] == 200 then
            break
        elseif r['status'] == 301 then
            url = url_join(url, r['headers']['location'])
            if last_err() then return end
        else
            return 'http error: ' .. r['status']
        end
    end

    local last_seen_html = html_select(r['text'], '.relativetime')
    local last_seen = strptime('%Y-%m-%d %H:%M:%SZ', last_seen_html['attrs']['title'])

    db_update('account', arg, {
        url=url,
        last_seen=sn0int_time_from(last_seen),
    })
end
