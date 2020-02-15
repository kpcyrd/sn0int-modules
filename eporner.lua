-- Description: TODO your description here
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: accounts:eporner.com

function parse_state(r)
    local status_img = html_select(r['text'], '#profile-h1-img')
    if status_img['attrs']['src']:find('online') ~= nil then
        return 'online'
    else
        return 'offline'
    end

end

function run(arg)
    local session = http_mksession()
    local url ='https://www.eporner.com/profile/' .. arg['username'] .. '/'
    local req = http_request(session, 'GET', 'https://www.eporner.com/profile/' .. arg['username'] .. '/', {})
    local r = http_fetch(req)

    local state = parse_state(r)
    db_activity({
        topic='kpcyrd/eporner:' .. arg['username'],
        time=sn0int_time(),
        content={
            state=state,
        },
    })

    local last_seen = nil

    local about = html_select_list(r['text'], '#aboutmebox li')
    for i=1, #about do
        local m = regex_find('^(.+): (.+)', about[i]['text'])
        if m then
            if m[2] == 'Joined' then
                -- TODO: add joined to database
                joined = strptime('%Y-%m-%d %H:%M', m[3])
            elseif m[2] == 'Last login' then
                last_seen = sn0int_time_from(strptime('%Y-%m-%d %H:%M', m[3]))
            end
        end
    end

    db_update('account', arg, {
        last_seen=last_seen,
        url=url,
    })
end
