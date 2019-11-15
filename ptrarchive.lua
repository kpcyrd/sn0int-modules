-- Description: Try to discover subdomains from ptrarchive.com
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: domains

function run(arg)
    local session = http_mksession()
    local req = http_request(session, 'GET', 'http://ptrarchive.com/tools/search4.htm', {
        query={
            label=arg['value'],
            date='ALL',
        }
    })
    req['cookies']['pa_id'] = session
    local r = http_fetch(req)

    local m = regex_find_all('\\S+', r['text'])
    for i=1, #m do
        local x = m[i][1]
        if not x:match('^automated_programs_unauthorized.') then
            local root = psl_domain_from_dns_name(x)
            if last_err() then
                clear_err()
            else
                if root == arg['value'] then
                    db_add('subdomain', {
                        domain_id=arg['id'],
                        value=x,
                    })
                end
            end
        end
    end
end
