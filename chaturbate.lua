-- Description: Collect information from chaturbate streams
-- Version: 0.3.0
-- License: GPL-3.0
-- Source: accounts:chaturbate.com

function resolve_external_link(href)
    local link = url_join('https://chaturbate.com/', href)
    local parts = url_parse(link)
    if not parts['params'] then return end
    return parts['params']['url']
end

service_map = {}
service_map['www.instagram.com']    = {'^/([^/]+)', 'instagram.com'}
service_map['twitter.com']          = {'^/([^/]+)', 'twitter.com'}
service_map['mobile.twitter.com']   = {'^/([^/]+)', 'twitter.com'}
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

function fetch_videoctx(session, user)
    local url = 'https://chaturbate.com/api/chatvideocontext/' .. user .. '/'

    local req = http_request(session, 'GET', url, {})
    local resp = http_send(req)
    if last_err() then return end
    if resp['status'] ~= 200 then return end

    local r = json_decode(resp['text'])
    if last_err() then return end

    local last_seen = nil
    local now = sn0int_time()
    local state = r['room_status']

    if state ~= 'offline' then
        debug('is online')
        last_seen = now
    end

    local apps_running = json_decode(r['apps_running'])

    db_activity({
        topic='kpcyrd/chaturbate:' .. user,
        time=now,
        content={
            state=state,
            room_title=r['room_title'],
            tfa_enabled=r['tfa_enabled'],
            num_viewers=r['num_viewers'],
            broadcaster_gender=r['broadcaster_gender'],
            allow_private_shows=r['allow_private_shows'],
            private_show_price=r['private_show_price'],
            private_min_minutes=r['private_min_minutes'],
            allow_show_recording=r['allow_show_recording'],
            spy_private_show_price=r['spy_private_show_price'],
            apps_running=apps_running,
            satisfaction_score=r['satisfaction_score'],
        },
    })

    return last_seen
end

function run(arg)
    local session = http_mksession()

    local user = arg['username']
    local last_seen = fetch_videoctx(session, user)
    if last_err() then return end

    local url = 'https://chaturbate.com/api/biocontext/' .. user .. '/'
    local req = http_request(session, 'GET', url, {})
    local resp = http_send(req)
    if last_err() then return end
    if resp['status'] ~= 200 then return end

    local r = json_decode(resp['text'])
    if last_err() then return end

    if not last_seen and r['last_broadcast'] then
        last_seen = strptime('%Y-%m-%dT%H:%M:%S.%f', r['last_broadcast'])
    end

    db_update('account', arg, {
        last_seen=last_seen,
        url='https://chaturbate.com/' .. user .. '/',
    })

    local links = html_select_list(r['about_me'], 'a[href^="/external_link/"]')
    for i=1, #links do
        local link = resolve_external_link(links[i]['attrs']['href'])
        if link then
            debug(link)
            detect_account(link)
            if last_err() then return end
        end
    end
end
