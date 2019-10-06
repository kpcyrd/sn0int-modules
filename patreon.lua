-- Description: Collect information from patreon profiles
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: accounts:patreon.com

function empty(x)
    return x and #x > 0
end

function add_facebook(x)
    if not empty(x) then return end
    local m = regex_find('www\\.facebook\\.com/([^/]+)', x)
    db_add('account', {
        service='facebook.com',
        username=m[2],
    })
end

function add_twitch(x)
    if not empty(x) then return end
    local m = regex_find('twitch\\.tv/([^/]+)', x)
    db_add('account', {
        service='twitch.tv',
        username=m[2],
    })
end

function add_twitter(x)
    if not empty(x) then return end
    db_add('account', {
        service='twitter.com',
        username=x,
    })
end

function add_youtube(x)
    if not empty(x) then return end
    local m = regex_find('youtube\\.com/(?:user/)?([^/]+)', x)
    db_add('account', {
        service='youtube.com',
        username=m[2],
    })
end

function add_instagram(x)
    if not empty(x) then return end
    local m = regex_find('instagram\\.com/([^/]+)', x)
    db_add('account', {
        service='instagram.com',
        username=m[2],
    })
end

function add_socials(social)
    -- TODO; remove this workaround
    if json_encode(social) == '{}' then return end

    if social['deviantart'] then
        info({TODO='deviantart', x=social['deviantart']})
    end
    if social['discord'] and json_encode(social['discord']) ~= '{}' then
        info({TODO='discord', x=social['discord']})
    end
    if social['facebook'] then
        info({TODO='facebook', x=social['facebook']})
    end
    if social['google'] then
        info({TODO='google', x=social['google']})
    end
    if social['instagram'] then
        add_instagram(social['instagram']['url'])
    end
    if social['spotify'] then
        info({TODO='spotify', x=social['spotify']})
    end
    if social['twitch'] then
        info({TODO='twitch', x=social['twitch']})
    end
    if social['twitter'] then
        info({TODO='twitter', x=social['twitter']})
    end
    if social['youtube'] then
        info({TODO='youtube', x=social['youtube']})
    end
end

function detect_video_channel(video)
    if not empty(video) then return end

    -- info('detect video channel from: ' .. video)

    local parts = url_parse(video)
    if last_err() then return clear_err() end
    local host = parts['host']

    if host == 'vimeo.com' then
        add_from_vimeo(video)
    elseif host == 'www.youtube.com' then
        add_from_youtube(parts['params']['v'])
    elseif host == 'youtu.be' then
        add_from_youtube(parts['path']:sub(2))
    end
end

function add_from_vimeo(video)
    local req = http_request(session, 'GET', video, {})
    local r = http_fetch(req)
    if last_err() then return end

    local ld = html_select(r['text'], 'script[type="application/ld+json"]')
    if last_err() then return end

    local ld = json_decode(ld['text'])
    if last_err() then return end

    local author = ld[1]['author']
    local m = regex_find('https://vimeo.com/([^/]+)', author['url'])

    db_add('account', {
        service='vimeo.com',
        username=m[2],
        displayname=author['name'],
    })
end

function add_from_youtube(video)
    -- info('TODO: youtube video: ' .. video)
end

function run(arg)
    local url = 'https://www.patreon.com/' .. arg['username']

    session = http_mksession()
    local req = http_request(session, 'GET', url, {})
    local r = http_fetch(req)
    if last_err() then return end

    local m = regex_find('https://www.patreon.com/api/user/(\\d+)', r['text'])
    if not m then return 'failed to detect uid' end
    local uid = m[2]
    --debug(uid)

    req = http_request(session, 'GET', 'https://www.patreon.com/api/user/' .. uid, {})
    r = http_fetch_json(req)
    if last_err() then return end

    local attrs = r['data']['attributes']

    db_update('account', arg, {
        displayname=attrs['full_name'],
        url=url,
    })

    add_facebook(attrs['facebook'])
    add_twitch(attrs['twitch'])
    add_twitter(attrs['twitter'])
    add_youtube(attrs['youtube'])
    add_socials(attrs['social_connections'])

    for i=1, #r['included'] do
        attrs = r['included'][i]['attributes']
        detect_video_channel(attrs['main_video_url'])
    end
end
