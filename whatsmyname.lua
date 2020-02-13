-- Description: Scan for social media accounts using WebBreachers WhatsMyName json
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: accounts

function escape(s)
    return s:gsub('[%-%.%+%[%]%(%)%$%^%%%?%*]','%%%1')
end

function check_account(site, url)
    if not site['valid'] then
        return set_err(site['name'] .. ' is currently disabled')
    end

    local session = http_mksession()
    debug('trying ' .. url .. '...')
    local req = http_request(session, 'GET', url, {
        timeout=5000
    })
    local r = http_send(req)
    if last_err() then return end

    if r['status'] == intval(site['account_existence_code']) and r['text']:find(escape(site['account_existence_string'])) ~= nil then
        return true
    end

    if r['status'] == intval(site['account_missing_code']) and r['text']:find(escape(site['account_missing_string'])) ~= nil then
        return false
    end

    set_err('neither existance- nor missing-rules matched')
end

function run(arg)
    local session = http_mksession()

    -- TODO: cache this file
    debug('fetching web_accounts_list.json')
    local req = http_request(session, 'GET', 'https://raw.githubusercontent.com/WebBreacher/WhatsMyName/master/web_accounts_list.json', {})
    local r = http_fetch_json(req)
    if last_err() then return end

    for i=1, #r['sites'] do
        local site = r['sites'][i]
        local url = site['check_uri']:gsub('{account}', arg['username'])

        local pretty_url = url
        if site['pretty_uri'] then
            pretty_url = site['pretty_uri']:gsub('{account}', arg['username'])
        end

        debug(site)

        local found = check_account(site, url)
        if last_err() then
            debug(last_err())
            clear_err()
        elseif found then
            local parts = url_parse(url)
            local domain = psl_domain_from_dns_name(parts['host'])

            db_add('account', {
                service=domain,
                username=arg['username'],
                url=pretty_url,
            })
        else
            debug('account doesn\'t exist')
        end
    end
end
