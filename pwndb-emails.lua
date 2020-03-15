-- Description: Read breached credentials for an email from pwndb hidden service (requires tor)
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: emails

function each_user(breach_id, email_id, domain, user)
    if json_encode(user) == '{}' then return end
    if user['domain'] ~= domain then return end

    db_add('breach-email', {
        breach_id=breach_id,
        email_id=email_id,
        password=user['password'],
    })
end

function run(arg)
    local proxy = getopt('proxy') or '127.0.0.1:9050'

    local m = regex_find('^([^@]+)@([^@]+)$', arg['value'])
    if not m then return end
    local domain = m[3]

    local session = http_mksession()
    local req = http_request(session, 'POST', 'http://pwndb2am4tzkvold.onion/', {
        proxy=proxy,
        form={
            luser=m[2],
            domain=domain,
            luseropr='0',
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
            each_user(breach_id, arg['id'], domain, user)
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

    each_user(breach_id, arg['id'], domain, user)
end
