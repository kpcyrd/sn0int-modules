-- Description: Index open directories
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: urls

function get_subdomain_id(url)
    local parts = url_parse(url)
    if last_err() then return end
    local subdomain = parts['host']
    local domain = psl_domain_from_dns_name(subdomain)
    if last_err() then return end

    local domain_id = db_add('domain', {
        value=domain,
    })
    if not domain_id then return end

    return db_add('subdomain', {
        domain_id=domain_id,
        value=subdomain,
    })
end

function add_url(url)
    local subdomain_id = get_subdomain_id(url)
    if not subdomain_id then return end

    db_add('url', {
        subdomain_id=subdomain_id,
        value=url,
        body='', -- TODO: this is setting the body to an empty string in 0.17.1
    })
end

function walk(base, body)
    local body = utf8_decode(body)
    if last_err() then return clear_err() end

    if not str_find(body, '<h1>Index of ') then
        debug('no open directory detected')
        return
    end

    local links = html_select_list(body, 'a')
    for i=1, #links do
        local link = url_join(base, links[i]['attrs']['href'])
        if str_find(link, base) == 1 and link ~= base then
            -- add discovered url
            add_url(link)
            if last_err() then return end

            -- in case of a directory, add to queue for fetching
            if link:match('/$') then
                queue[#queue+1] = link
            end
        end
    end
end

function fetch(url)
    debug('fetch ' .. url)
    local req = http_request(session, 'GET', url, {
        timeout=10000
    })
    local r = http_send(req)

    local subdomain_id = get_subdomain_id(url)
    if subdomain_id then
        db_add('url', {
            subdomain_id=subdomain_id,
            value=url,
            status=r['status'],
            body=r['text'],
            redirect=r['headers']['location'],
        })
    end

    return r
end

function run(arg)
    queue = {}
    session = http_mksession()

    walk(arg['value'], arg['body'])
    if last_err() then return end

    local i = 1
    while i <= #queue do
        local url = queue[i]

        local r = fetch(url)
        if last_err() then
            warn(last_err())
            clear_err()
        else
            walk(url, r['text'])
            if last_err() then return end
        end

        i = i + 1
    end
end
