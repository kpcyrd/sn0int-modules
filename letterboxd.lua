-- Description: Collect information from letterboxd.com profiles
-- Version: 0.2.0
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

function read_activity(user)
    local after = nil
    while true do
        local activity_url = 'https://letterboxd.com/ajax/activity-pagination/' .. user .. '/'
        local req = http_request(session, 'GET', activity_url, {
            query={
                after=after,
            }
        })
        local r = http_fetch(req)
        if last_err() then return end

        local activity = html_select_list(r['text'], 'section')

        local last_seen = nil
        for i=1, #activity do
            local activity_id = activity[i]['attrs']['data-activity-id']
            after = activity_id

            local time = html_select(activity[i]['html'], 'time')
            if last_err() then
                clear_err()
                return last_seen
            end
            time = strptime('%Y-%m-%dT%H:%M:%SZ', time['attrs']['datetime'])

            -- update last_seen
            if not last_seen or last_seen < time then
                last_seen = time
            end

            local target = html_select(activity[i]['html'], 'a.target, .linked-film-poster')
            if last_err() then return end

            local href = target['attrs']['href']
            if not href then
                -- fallback in case it's a poster box
                href = target['attrs']['data-target-link']
            end

            local movie = url_join('https://letterboxd.com/', href)

            local reinserted = db_activity({
                topic='kpcyrd/letterboxd:' .. user,
                time=sn0int_time_from(time),
                uniq='id:' .. activity_id,
                content={
                    movie=movie,
                },
            })

            if reinserted then
                return last_seen
            end
        end
    end
end

function run(arg)
    local user = arg['username']

    session = http_mksession()
    local url = 'https://letterboxd.com/' .. user .. '/'
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

    local last_seen = read_activity(user)
    if last_err() then return end

    if last_seen then
        update['last_seen'] = sn0int_time_from(last_seen)
    end

    db_update('account', arg, update)
end
