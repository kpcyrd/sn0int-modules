-- Description: Verify protonmail addresses through protonmail keyserver
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: emails

function run(arg)
    local domain = arg['value']:match('@[^@]+$')
    if domain ~= '@protonmail.com' and domain ~= '@protonmail.ch' then
        return
    end

    local session = http_mksession()
    local req = http_request(session, 'GET', 'https://api.protonmail.ch/pks/lookup', {
        query={
            op='get',
            search=arg['value'],
        }
    })
    local r = http_send(req)
    if last_err() then return end

    if r['status'] == 404 then
        db_update('email', arg, {
            valid=false,
        })
        return
    end
    if r['status'] ~= 200 then
        return set_err('http status error: ' .. r['status'])
    end

    local key = pgp_pubkey_armored(r['text'])
    if last_err() then return end
    debug(key)

    db_update('email', arg, {
        valid=true,
    })
end
