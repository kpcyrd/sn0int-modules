-- Description: Collect information from letterboxd.com profiles
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: accounts:letterboxd.com

service_map = {}
service_map['instagram.com']        = {'^/([^/]+)', 'instagram.com'}
service_map['www.instagram.com']    = {'^/([^/]+)', 'instagram.com'}
service_map['twitter.com']          = {'^/([^/]+)', 'twitter.com'}
service_map['www.patreon.com']      = {'^/([^/]+)', 'patreon.com'}
service_map['twitter.com']          = {'^/([^/]+)', 'twitter.com'}
service_map['vimeo.com']            = {'^/(\\d*[^/\\d]+[^/]+)', 'vimeo.com'}

function detect_account(link)
    local parts = url_parse(link)
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
    local url = 'https://letterboxd.com/' .. arg['username'] .. '/'
    local update = {
        url=url,
    }

    local req = http_request(session, 'GET', url, {})
    local r = http_fetch(req)
    if last_err() then return end

    local links = html_select_list(r['text'], '.icon-website, .icon-twitter, #person-bio a')
    for i=1, #links do
        detect_account(links[i]['attrs']['href'])
    end

    local activity_url = 'https://letterboxd.com/ajax/activity-pagination/' .. arg['username'] .. '/'
    req = http_request(session, 'GET', activity_url, {})
    r = http_fetch(req)
    if last_err() then return end

    local activity = html_select_list(r['text'], 'time')
    if #activity > 0 then
        local last_activity = activity[1]['attrs']['datetime']
        -- convert to timestamp
        last_activity = strptime('%Y-%m-%dT%H:%M:%SZ', last_activity)
        -- convert to sn0int datetime
        update['last_seen'] = strftime('%Y-%m-%dT%H:%M:%S', last_activity)
    end

    db_update('account', arg, update)
end
