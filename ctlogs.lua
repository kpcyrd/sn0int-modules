-- Description: Query certificate transparency logs to discover subdomains
-- Version: 0.7.0
-- Source: domains
-- License: GPL-3.0

function each_name(target, name)
    debug(name)

    if name:find('*.') == 1 then
        -- TODO: consider trimming `*.` and retry
        -- ignore wildcard domains
        return
    end

    -- the cert might be valid for subdomains that do not belong to our target domain
    local psl_domain = psl_domain_from_dns_name(name)
    if not any_domain and target ~= psl_domain and str_find(name, '.' .. target) ~= #name - #target then
        return
    end

    local domain_id = db_add('domain', {
        value=psl_domain,
    })
    if domain_id == nil then return end

    db_add('subdomain', {
        domain_id=domain_id,
        value=name,
    })
end

function run(arg)
    local full = getopt('full') ~= nil
    any_domain = getopt('any-domain') ~= nil

    domains = {}
    domains[arg['value']] = arg['id']

    local session = http_mksession()
    local req = http_request(session, 'GET', 'https://crt.sh/', {
        query={
            q='%.' .. arg['value'],
            output='json'
        }
    })

    local certs = http_fetch_json(req)
    if last_err() then return end

    for i=1, #certs do
        local c = certs[i]
        debug(c)

        if full then
            -- fetch certificate
            req = http_request(session, 'GET', 'https://crt.sh/', {
                query={
                    d=strval(c['id']),
                }
            })
            local r = http_fetch(req)
            if last_err() then return end

            -- iterate over all valid names
            local crt = x509_parse_pem(r['text'])
            if last_err() then return end

            local names = crt['valid_names']
            for j=1, #names do
                each_name(arg['value'], names[j])
            end
        else
            local m = regex_find_all('.+', c['name_value'])
            if m then
                for j=1, #m do
                    each_name(arg['value'], m[j][1])
                end
            end
        end
    end
end
