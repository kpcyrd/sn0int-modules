-- Description: Collect accounts and infos from pornhub profiles
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: accounts:pornhub.com

service_map = {}
service_map['www.instagram.com']    = {'^/([^/\\?]+)', 'instagram.com'}
service_map['twitter.com']          = {'^/@?([^/\\?]+)', 'twitter.com'}
service_map['www.twitter.com']      = {'^/@?([^/\\?]+)', 'twitter.com'}
service_map['www.modelhub.com']     = {'^/([^/\\?]+)', 'modelhub.com'}
service_map['fancentro.com']        = {'^/([^/\\?]+)', 'fancentro.com'}
-- for some reason a few profiles link to `/add/fancentro.com/USERNAME`
service_map['www.snapchat.com']     = {'^/add/(?:fancentro.com/)?([^/\\?]+)', 'snapchat.com'}

function detect_account(link)
    if not link then return end
    debug(link)

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

function fetch(user)
    local url = 'https://www.pornhub.com/users/' .. user
    while true do
        local req = http_request(session, 'GET', url, {})
        local r = http_send(req)
        if last_err() then return end

        if r['status'] == 200 then
            return {
                url=url,
                text=r['text'],
            }
        elseif r['status'] == 301 then
            url = url_join(url, r['headers']['location'])
            debug('redirect: ' .. url)
        else
            return set_err('http error: ' .. r['status'])
        end
    end
end

function trim(text)
    text = text:gsub('\n', ' ')
    local m = regex_find('^\\s*(.*?)\\s*$', text)
    return m[2]
end

function select_name(html)
    local name = html_select(html, 'h1[itemprop="name"]')
    if not last_err() then
        return trim(name['text'])
    end

    clear_err()
    name = html_select(html, '.profileUserName a')
    if not last_err() then
        return trim(name['text'])
    end

    clear_err()
end

function run(arg)
    session = http_mksession()

    local r = fetch(arg['username'])
    if last_err() then return end

    local displayname = select_name(r['text'])

    local last_seen = nil
    local online_status = html_select_list(r['text'], '.onlineStatus')
    if #online_status > 0 then
        last_seen = datetime()
    end

    local links = html_select_list(r['text'], 'aside .about a')
    for i=1, #links do
        detect_account(links[i]['attrs']['href'])
    end

    local infos = html_select_list(r['text'], '.infoPiece')
    for i=1, #infos do
        -- info(infos[i])
        local text = infos[i]['text']:gsub('\n', ' ')
        local m = regex_find('^\\s*([^:]+):\\s+(.+?)\\s*$', text)
        if m then
            local key = m[2]
            local value = m[3]
            debug({key, value})
            if key == 'Birthday' then
                -- TODO: support this field
                debug('Birthday: ' .. value)
            end
        end
    end

    db_update('account', arg, {
        displayname=displayname,
        url=r['url'],
        last_seen=last_seen,
    })
end
