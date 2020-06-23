-- Description: Request subdomains from spyse.com
-- Version: 0.2.0
-- License: GPL-3.0
-- Source: domains
-- Keyring-Access: spyse

function run(arg)
    local key = keyring('spyse')[1]
    if not key then
        return 'Missing required spyse access key'
    end

    local session = http_mksession()

    local headers = {}
    headers['Authorization'] = 'Bearer ' .. key['access_key']

    local page = 0
    local limit = 50
    while true do
        local req = http_request(session, 'GET', 'https://api.spyse.com/v3/data/domain/subdomain', {
            headers=headers,
            query={
                limit=strval(limit),
                offset=strval(page * limit),
                domain=arg['value'],
            }
        })
        debug('sending request for page #' .. page)
        local r = http_fetch_json(req)
        if last_err() then return end

        local data = r['data']['items']

        if #data == 0 then
            break
        end

        for i=1, #data do
            local record = data[i]
            db_add('subdomain', {
                domain_id=arg['id'],
                value=record['name'],
            })
        end

        page = page+1
    end
end
