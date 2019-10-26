-- Description: TODO your description here
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: accounts:npmjs.org

service_map = {}
service_map['twitter.com']          = {'^/([^/]+)', 'twitter.com'}
service_map['github.com']           = {'^/([^/]+)', 'github.com'}

function each_link(href)
    local parts = url_parse(href)
    if last_err() then return clear_err() end
    local host = parts['host']

    local service = service_map[host]
    if service then
        local m = regex_find(service[1], parts['path'])
        if m then
            db_add('account', {
                service=service[2],
                username=m[2],
            })
        end
    end
end

function run(arg)
    local session = http_mksession()

    local url = 'https://registry.npmjs.org/-/user/org.couchdb.user:' .. arg['username']
    local req = http_request(session, 'GET', url, {})
    local r = http_fetch_json(req)
    if last_err() then return end

    url = 'https://www.npmjs.com/~' .. arg['username']

    db_update('account', arg, {
        email=r['email'],
        url=url,
    })

    -- TODO: check if there's a better way to get twitter/github
    req = http_request(session, 'GET', url, {})
    r = http_fetch(req)
    if last_err() then return end

    local links = html_select_list(r['text'], 'main a')
    for i=1, #links do
        each_link(links[i]['attrs']['href'])
        if last_err() then return end
    end
end
