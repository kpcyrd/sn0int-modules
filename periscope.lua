-- Description: Collect broadcasts from a periscope account
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: accounts:pscp.tv

DATE_FORMAT = '%Y-%m-%dT%H:%M:%S%.fZ'

function download_avatar(user, skip_avatar)
    if skip_avatar then return end

    if user['avatarUrl'] then
        local req = http_request(session, 'GET', user['avatarUrl'], {
            into_blob=true,
        })
        local r = http_fetch(req)
        if last_err() then return end

        db_add('image', {
            value=r['blob'],
        })

        return r['blob']
    end
end

function detect_twitter(user)
    if user['twitterUrl'] then
        local name = user['twitterUrl']:match('https://twitter.com/([^/]+)')
        db_add('account', {
            service='twitter.com',
            username=name,
        })
    end
end

function run(arg)
    local skip_avatar = getopt('skip-avatar')

    session = http_mksession()
    local url = 'https://www.pscp.tv/' .. arg['username']
    local req = http_request(session, 'GET', url, {})
    local r = http_fetch(req)
    if last_err() then return end

    -- get the state
    local container = html_select(r['text'], '#page-container')
    if last_err() then return end
    local data = json_decode(container['attrs']['data-store'])
    if last_err() then return end

    -- update the user
    local uid = data['UserBroadcastHistory']['userId']
    local user = data['UserCache']['users'][uid]['user']
    local profile_pic = download_avatar(user, skip_avatar)
    if last_err() then return end

    -- info(user['created_at'])

    db_update('account', arg, {
        displayname=user['display_name'],
        url=user['canonicalUrl'],
        profile_pic=profile_pic,
    })

    detect_twitter(user)

    -- loop over broadcasts
    local broadcasts = data['UserBroadcastHistoryCache']['histories'][uid]['broadcastIds']
    for i=1, #broadcasts do
        local bc = data['BroadcastCache']['broadcasts'][broadcasts[i]]['broadcast']['data']
        -- info(bc)

        local canonical_url = 'https://www.pscp.tv/' .. bc['username'] .. '/' .. bc['id']
        local tweet_url = nil
        if bc['twitter_username'] and bc['tweet_id'] then
            tweet_url = 'https://twitter.com/' .. bc['twitter_username'] .. '/status/' .. bc['tweet_id']
        end

        local latitude = nil
        local longitude = nil
        if bc['has_location'] then
            latitude = bc['ip_lat']
            longitude = bc['ip_lng']
        end

        local time_created = strptime(DATE_FORMAT, bc['created_at'])
        db_activity({
            topic='kpcyrd/periscope:' .. arg['username'],
            time=sn0int_time_from(time_created),
            uniq=bc['id'] .. '/created',
            latitude=latitude,
            longitude=longitude,
            content={
                id=bc['id'],
                canonical_url=canonical_url,
                broadcast_source=bc['broadcast_source'],

                country=bc['country'],
                country_state=bc['country_state'],
                city=bc['city'],

                status=bc['status'],
                language=bc['language'],
                user_id=bc['user_id'],

                twitter_username=bc['twitter_username'],
                tweet_id=bc['tweet_id'],
                tweet_url=tweet_url,
            }
        })

        if bc['start'] then
            local time_start = strptime(DATE_FORMAT, bc['start'])
            db_activity({
                topic='kpcyrd/periscope:' .. arg['username'],
                time=sn0int_time_from(time_start),
                uniq=bc['id'] .. '/start',
                content={
                    id=bc['id'],
                },
            })
        end

        if bc['end'] then
            local time_end = strptime(DATE_FORMAT, bc['end'])
            db_activity({
                topic='kpcyrd/periscope:' .. arg['username'],
                time=sn0int_time_from(time_end),
                uniq=bc['id'] .. '/end',
                content={
                    id=bc['id'],
                },
            })
        end
    end

    -- TODO: detect if a stream is active
end
