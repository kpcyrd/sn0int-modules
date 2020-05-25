-- Description: Scan for open wkd directories and farm emails from pubkeys
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: subdomains

function fetch_key(url)
    debug(url)
    local req = http_request(session, 'GET', url, {
        binary=true,
    })
    local r = http_fetch(req)
    if last_err() then return end

    local k = pgp_pubkey(r['binary'])
    if last_err() then return end

    for i=1, #k['uids'] do
        local m = regex_find('(.+) <([^< ]+@[^< ]+)>$', k['uids'][i])
        if m then
            db_add('email', {
                value=m[3],
                displayname=m[2],
            })
        end
    end
end

function fetch_index(url)
    local req = http_request(session, 'GET', url, {})
    local r = http_send(req)
    if last_err() then return end

    if r['status'] ~= 200 then
        return
    end

    local links = html_select_list(r['text'], 'a')
    for i=1, #links do
        local href = links[i]['attrs']['href']
        if href and href ~= '../' then
            local key = url_join(url, href)
            fetch_key(key)
            local err = last_err()
            if err then
                warn('err(fetch_key): ' .. err)
                clear_err()
            end
        end
    end
end

function run(arg)
    session = http_mksession()

    fetch_index('https://openpgpkey.' .. arg['value'] .. '/.well-known/openpgpkey/' .. arg['value'] .. '/hu/')
    err = last_err()
    if err then
        debug(err)
        clear_err()
    end

    fetch_index('https://' .. arg['value'] .. '/.well-known/openpgpkey/hu/')
    err = last_err()
    if err then
        debug(err)
        clear_err()
    end
end
