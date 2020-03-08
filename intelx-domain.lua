-- Description: Discover subdomains, emails and urls from intelx.io
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: domains
-- Keyring-Access: intelx

function add_email(value)
    debug({email=value})
    db_add('email', {
        value=value,
    })
end

function add_domain(value)
    debug({domain=value})
    local psl_domain = psl_domain_from_dns_name(value)
    local domain_id = db_add('domain', {
        value=psl_domain,
    })
    if not domain_id then return end
    return db_add('subdomain', {
        domain_id=domain_id,
        value=value,
    })
end

function add_url(value)
    debug({url=value})
    local parts = url_parse(value)
    local host = parts['host']
    local subdomain_id = add_domain(parts['host'])
    if not subdomain_id then return end
    db_add('url', {
        subdomain_id=subdomain_id,
        value=value,
    })
end

function get_key()
    local key = keyring('intelx')[1]
    if key then
        return key['access_key']
    else
        return '9df61df0-84f7-4dc7-b34c-8ccfb8646ace' -- public api key
    end
end

function run(arg)
    local headers = {}
    headers['x-key'] = get_key()

    local session = http_mksession()
    local req = http_request(session, 'POST', 'https://public.intelx.io/phonebook/search', {
        headers=headers,
        json={
            term=arg['value'],
            -- buckets=[],
            lookuplevel=0,
            maxresults=10,
            timeout=0,
            datefrom="",
            dateto="",
            sort=4,
            media=0,
            -- terminate=[],
        },
    })
    local r = http_fetch_json(req)
    if last_err() then return end

    if r['status'] == 1 then
        return 'invalid term used'
    elseif r['status'] == 2 then
        return 'reached the max number of concurrent connections for this api key'
    elseif r['status'] > 0 then
        return 'unknown status code: ' .. r['status']
    end

    debug({search=r})
    local id = r['id']

    local status = 3
    while status == 3 or status == 0 do
        req = http_request(session, 'GET', 'https://public.intelx.io/phonebook/search/result', {
            query={
                id=id,
            },
            headers=headers,
        })
        local r = http_fetch_json(req)
        if last_err() then return end
        status = r['status']

        local selectors = r['selectors']
        for i=1, #selectors do
            local s = selectors[i]

            if s['selectortype'] == 1 then
                add_email(s['selectorvalue'])
            elseif s['selectortype'] == 2 then
                add_domain(s['selectorvalue'])
            elseif s['selectortype'] == 3 then
                add_url(s['selectorvalue'])
            elseif s['selectortype'] == 23 then
                add_url(s['selectorvalue'])
            else
                info({unknown=s})
            end
        end
        sleep(1)
    end
end
