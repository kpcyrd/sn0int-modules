-- Description: Collect subdomains from virustotal data
-- Version: 0.1.2
-- License: GPL-3.0
-- Source: domains

function run(arg)
    local session = http_mksession(session)
    local url = 'https://www.virustotal.com/ui/domains/' .. arg['value'] .. '/subdomains?limit=40'

    while url do
        ratelimit_throttle('virustotal', 5, 15000)

        local req = http_request(session, 'GET', url, {})
        local r = http_fetch_json(req)
        if last_err() then return end

        for i=1, #r['data'] do
            local d = r['data'][i]

            local m = regex_find('[^\\.].*[^\\.]', d['id'])
            if m then
                local name = m[1]

                db_add('subdomain', {
                    domain_id=arg['id'],
                    value=name,
                })
                if last_err() then return end
            end
        end

        url = r['links']['next']
    end
end
