-- Description: Query pgp keyserver for email addresses
-- Version: 0.4.0
-- Source: domains
-- License: GPL-3.0

function run(arg)
    local domain = arg['value']

    local lookup_url = 'https://keyserver.ubuntu.com/pks/lookup'

    session = http_mksession()
    local req = http_request(session, 'GET', lookup_url, {
        query={
            search=domain,
            fingerprint='on',
            op='index',
        }
    })

    local resp = http_send(req)
    if last_err() then return end
    if resp['status'] ~= 200 then return 'http error: ' .. resp['status'] end

    links = html_select_list(resp['text'], 'a')
    debug('keys found: ' .. #links)
    for i=1, #links do
        href = links[i]['attrs']['href']

        if href:find('/pks/lookup%?op=get&search=') == 1 then
            url = url_join(lookup_url, href)

            debug(url)
            req = http_request(session, 'GET', url, {})
            resp = http_send(req)
            -- TODO: do not abort script if one attempt fails
            if last_err() then return end

            if resp['status'] ~= 200 then
                error('http error: ' .. url .. ' => ' .. resp['status'])
            else
                pubkey = pgp_pubkey_armored(resp['text'])
                if last_err() then
                    warn(last_err())
                    clear_err()
                else
                    -- print(pubkey)

                    local emails = {}
                    local domain_matched = false

                    -- TODO: ensure at least one email matches our target domain
                    if pubkey['uids'] then
                        for j=1, #pubkey['uids'] do
                            local m = regex_find("(.+) <([^< ]+@[^< ]+)>$", pubkey['uids'][j])
                            if m then
                                local email = m[3]:lower()
                                emails[#emails+1] = {
                                    value=email,
                                    displayname=m[2],
                                }

                                if email:match('@' .. domain .. '$') then
                                    domain_matched = true
                                end
                            end
                        end
                    end

                    if domain_matched then
                        for j=1, #emails do
                            db_add('email', emails[j])
                        end
                    end
                end
            end
        end
    end
end
