-- Description: Add mods in chaturbate rooms to scope
-- Version: 0.2.0
-- License: GPL-3.0
-- Source: accounts:chaturbate.com

function run(arg)
    -- getting csrf token
    local session = http_mksession()
    local req = http_request(session, 'GET', 'https://chaturbate.com/', {})
    local r = http_fetch(req)
    if last_err() then return end
    req = http_request(session, 'GET', 'https://chaturbate.com/', {})
    local csrf = req['cookies']['csrftoken']

    local room = arg['username']

    -- fetching room list
    headers = {}
    headers['Referer'] = 'https://chaturbate.com/' .. room .. '/'
    headers['X-CSRFToken'] = csrf
    req = http_request(session, 'POST', 'https://chaturbate.com/api/getchatuserlist/', {
        headers=headers,
        form={
            sort_by='a',
            private='false',
            roomname=room,
        },
    })
    local r = http_fetch(req)

    local m = regex_find_all(',([^,]+?)\\|m', r['text'])
    for i=1, #m do
        local user = m[i][2]
        local now = sn0int_time()
        db_add('account', {
            service='chaturbate.com',
            username=user,
            last_seen=now,
        })
        db_activity({
            topic='kpcyrd/chaturbate-mods:' .. user,
            time=now,
            content={
                moderates=room,
            },
        })
    end
end
