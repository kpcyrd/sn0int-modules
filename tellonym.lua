-- Description: Import data from tellonym accounts
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: accounts:tellonym.me

DATE_FORMAT = '%Y-%m-%dT%H:%M:%S%.fZ'

function fetch_avatar(r)
    local filename = r['avatarFileName']
    if not filename then return end

    local url = 'https://userimg.tellonym.me/xs/' .. filename
    local req = http_request(session, 'GET', url, {
        into_blob=true,
    })
    local r = http_fetch(req)
    if last_err() then return end

    db_add('image', {
        value=r['blob'],
    })
    return r['blob']
end

function add_answers(username, r)
    local last_seen = nil

    for i=1, #r['answers'] do
        local answer = r['answers'][i]

        if answer['type'] ~= 'AD' then
            debug(answer)
            local time_created = strptime(DATE_FORMAT, answer['createdAt'])

            if not last_seen or time_created > last_seen then
                last_seen = time_created
            end

            db_activity({
                topic='kpcyrd/tellonym:' .. username,
                time=sn0int_time_from(time_created),
                uniq=strval(answer['id']),
                content={
                    _type=answer['type'],
                    tell=answer['tell'],
                    answer=answer['answer'],
                },
            })

            ctr = ctr+1
            prev_id = strval(answer['id'])
        end
    end

    return last_seen
end

function run(arg)
    local skip_history = getopt('skip-history')

    local url = 'https://api.tellonym.me/profiles/name/' .. arg['username'] .. '?limit=25'
    session = http_mksession()
    local req = http_request(session, 'GET', url, {})
    local r = http_fetch_json(req)
    if last_err() then return end

    debug(r)
    local profile_pic = fetch_avatar(r)

    for i=1, #r['linkData'] do
        local link = r['linkData'][i]

        if link['type'] == 0 then
            db_add('account', {
                service='instagram.com',
                username=link['link'],
            })
        elseif link['type'] == 1 then
            db_add('account', {
                service='snapchat.com',
                username=link['link'],
            })
        elseif link['type'] == 3 then
            db_add('account', {
                service='twitter.com',
                username=link['link'],
            })
        end
    end

    local uid = strval(r['id'])
    ctr = 0
    prev_id = nil

    local last_seen = add_answers(arg['username'], r)

    if r['isActive'] then
        local now = time_unix()

        db_activity({
            topic='kpcyrd/tellonym:' .. arg['username'],
            time=sn0int_time_from(now),
            content={
                t='online',
            },
        })

        if last_seen < now then
            last_seen = now
        end
    end

    if last_seen then
        last_seen = sn0int_time_from(last_seen)
    end

    db_update('account', arg, {
        displayname=r['displayName'],
        url='https://tellonym.me/' .. arg['username'],
        last_seen=last_seen,
        profile_pic=profile_pic,
    })

    if skip_history then return end

    while true do
        local req = http_request(session, 'GET', 'https://api.tellonym.me/answers/' .. uid, {
            query={
                oldestId=prev_id,
                userId=uid,
                limit='25',
                pos=strval(ctr),
            }
        })
        debug(req)
        local r = http_fetch_json(req)
        if last_err() then return end

        debug(r)
        add_answers(arg['username'], r)

        if #r['answers'] == 0 then
            break
        end
    end
end
