-- Description: Read tx history of transparent zcash addresses
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: cryptoaddrs:zec

function run(arg)
    COIN = 100000000

    local url = 'https://api.zcha.in/v2/mainnet/accounts/' ..arg['value']

    local session = http_mksession()
    local req = http_request(session, 'GET', url, {})
    local r = http_fetch_json(req)
    if last_err() then return end

    local update = {
        balance=intval(r['balance'] * COIN),
        received=intval(r['totalRecv'] * COIN),
    }

    if r['firstSeen'] > 0 then
        update['first_seen'] = sn0int_time_from(r['firstSeen'])
    end
    if r['lastSeen'] > 0 then
        update['last_withdrawal'] = sn0int_time_from(r['lastSeen'])
    end

    db_update('cryptoaddr', arg, update)
end
