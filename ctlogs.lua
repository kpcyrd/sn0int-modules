-- Description: Query certificate transparency logs to discover subdomains
-- Version: 0.6.1
-- Source: domains
-- License: GPL-3.0

function each_name(name)
    if seen[name] == 1 then
        return
    end
    seen[name] = 1
    debug(name)

    if name:find('*.') == 1 then
        -- ignore wildcard domains
        return
    end

    -- the cert might be valid for subdomains that do not belong to the
    -- domain we started with
    local psl_domain = psl_domain_from_dns_name(name)
    local domain_id = domains[psl_domain]
    if domain_id == nil then
        if any_domain then
            -- unknown domains should be added to database
            domain_id = db_add('domain', {
                value=psl_domain,
            })
        else
            -- only use domains that are already in scope
            domain_id = db_select('domain', psl_domain)
        end

        -- if we didn't get a valid id, skip
        if domain_id == nil then
            return
        end

        domains[psl_domain] = domain_id
    end

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

    seen = {}

    for i=1, #certs do
        local c = certs[i]
        debug(c)

        if full then
            -- fetch certificate
            req = http_request(session, 'GET', 'https://crt.sh/', {
                query={
                    d=c['id'] .. '', -- TODO: find nicer way for tostring
                }
            })
            local r = http_fetch(req)
            if last_err() then return end

            -- iterate over all valid names
            local crt = x509_parse_pem(r['text'])
            if last_err() then return end

            local names = crt['valid_names']
            for j=1, #names do
                each_name(names[j])
            end
        else
            local m = regex_find_all('.+', c['name_value'])
            if m then
                for j=1, #m do
                    each_name(m[j][1])
                end
            end
        end
    end
end
