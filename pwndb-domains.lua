-- Description: Read breached credentials by domain from pwndb hidden service (requires tor)
-- Version: 0.1.1
-- License: GPL-3.0
-- Source: domains

function each_user(breach_id, domain, user)
    if json_encode(user) == '{}' then return end
    if user['domain'] ~= domain then return end

    email_id = db_add('email', {
        value=user['name'] .. '@' .. user['domain'],
    })
    if not email_id then return end

    db_add('breach-email', {
        breach_id=breach_id,
        email_id=email_id,
        password=user['password'],
    })
end

function run(arg)
    local proxy = getopt('proxy') or '127.0.0.1:9050'

    local session = http_mksession()
    local req = http_request(session, 'POST', 'http://pwndb2am4tzkvold.onion/', {
        proxy=proxy,
        form={
            luser='%',
            domain=arg['value'],
            luseropr='1',
            domainopr='0',
            submitform='em',
        },
    })
    local r = http_fetch(req)
    local err = last_err()
    if err then
        return set_err('Check tor is running! ' .. err)
    end

    local pre = html_select(r['text'], 'pre')
    local lines = regex_find_all('.+', pre['text'])

    local breach_id = db_add('breach', {
        value='pwndb',
    })

    local user = {}
    for i=1, #lines do
        local l = lines[i][1]
        debug(l)

        if l == 'Array' then
            each_user(breach_id, arg['value'], user)
            user = {}
        end

        m = regex_find('^\\s+\\[luser\\] => (.+)$', l)
        if m then
            user['name'] = m[2]
        end

        m = regex_find('^\\s+\\[domain\\] => (.+)$', l)
        if m then
            user['domain'] = m[2]
        end

        m = regex_find('^\\s+\\[password\\] => (.+)$', l)
        if m then
            user['password'] = m[2]
        end
    end

    each_user(breach_id, arg['value'], user)
end
