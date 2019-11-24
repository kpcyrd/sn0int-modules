-- Description: Monitor rooms for non-broadcasting users
-- Version: 0.1.1
-- License: GPL-3.0

function run()
    local room = getopt('room')
    if not room then
        return 'You need to set a room to monitor'
    end

    -- getting csrf token
    local session = http_mksession()
    local req = http_request(session, 'GET', 'https://chaturbate.com/', {})
    local r = http_fetch(req)
    if last_err() then return end
    req = http_request(session, 'GET', 'https://chaturbate.com/', {})
    local csrf = req['cookies']['csrftoken']

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

    local m = regex_find_all(',([^,]+?)\\|', r['text'])
    debug('found users: ' .. #m)
    for i=1, #m do
        -- if user is in scope, update last_seen
        local user = m[i][2]
        local id = db_select('account', 'chaturbate.com/' .. user)
        if id then
            debug('found in ' .. room .. ': ' .. user)
            db_add('account', {
                service='chaturbate.com',
                username=user,
                last_seen=datetime(),
            })
        end
    end
end
