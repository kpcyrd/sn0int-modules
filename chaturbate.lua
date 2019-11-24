-- Description: Collect information from chaturbate streams
-- Version: 0.2.0
-- License: GPL-3.0
-- Source: accounts:chaturbate.com

function resolve_external_link(href)
    local link = url_join('https://chaturbate.com/', href)
    local parts = url_parse(link)
    return parts['params']['url']
end

service_map = {}
service_map['www.instagram.com']    = {'^/([^/]+)', 'instagram.com'}
service_map['twitter.com']          = {'^/([^/]+)', 'twitter.com'}
service_map['www.patreon.com']      = {'^/([^/]+)', 'patreon.com'}
service_map['www.twitch.tv']        = {'^/([^/]+)', 'twitch.tv'}

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

    local url = 'https://chaturbate.com/api/chatvideocontext/' .. arg['username'] .. '/'
    local req = http_request(session, 'GET', url, {})
    local r = http_fetch_json(req)
    if last_err() then return end

    local last_seen = nil
    if r['room_status'] == 'offline' then
        debug('is offline')
    else
        debug('is online')
        last_seen = datetime()
    end

    debug('tfa_enabled=' .. r['tfa_enabled'])
    debug('private_show_price=' .. r['private_show_price'])
    debug('private_min_minutes=' .. r['private_min_minutes'])
    debug('allow_show_recording=' .. r['allow_show_recording'])
    debug('apps_running=' .. r['apps_running'])

    url = 'https://chaturbate.com/' .. arg['username'] .. '/'
    req = http_request(session, 'GET', url, {})
    r = http_fetch(req)
    if last_err() then return end

    db_update('account', arg, {
        last_seen=last_seen,
        url=url,
    })

    local links = html_select_list(r['text'], 'a[href^="/external_link/"]')
    for i=1, #links do
        local link = resolve_external_link(links[i]['attrs']['href'])
        debug(link)
        detect_account(link)
        if last_err() then return end
    end
end
