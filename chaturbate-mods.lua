-- Description: Add mods in chaturbate rooms to scope
-- Version: 0.1.0
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

    -- fetching room list
    headers = {}
    headers['Referer'] = 'https://chaturbate.com/' .. arg['username'] .. '/'
    headers['X-CSRFToken'] = csrf
    req = http_request(session, 'POST', 'https://chaturbate.com/api/getchatuserlist/', {
        headers=headers,
        form={
            sort_by='a',
            private='false',
            roomname=arg['username'],
        },
    })
    local r = http_fetch(req)

    local m = regex_find_all(',([^,]+?)\\|m', r['text'])
    for i=1, #m do
        local user = m[i][2]
        db_add('account', {
            service='chaturbate.com',
            username=user,
            last_seen=datetime(),
        })
    end
end
