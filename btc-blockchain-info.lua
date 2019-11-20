-- Description: Read tx history of bitcoin addresses
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: cryptoaddrs:btc

function run(arg)
    local url = 'https://blockchain.info/rawaddr/' .. arg['value']

    local session = http_mksession()
    local req = http_request(session, 'GET', url, {})
    local r = http_fetch_json(req)
    if last_err() then return end

    local last_withdrawal = nil
    for i=1, #r['txs'] do
        local tx = r['txs'][i]
        local time = sn0int_time_from(tx['time'])
        local inputs = tx['inputs']
        for j=1, #inputs do
            if inputs[j]['prev_out'] and inputs[j]['prev_out']['addr'] == arg['value'] then
                last_withdrawal = time
            end
        end
    end

    local first_seen = nil
    local n_tx = r['n_tx']
    if n_tx > 0 then
        local first_tx = nil
        if n_tx > 50 then
            -- fetch last page
            url = 'https://blockchain.info/rawaddr/' .. arg['value'] .. '?offset=' .. (n_tx-1)
            req = http_request(session, 'GET', url, {})
            r = http_fetch_json(req)
            if last_err() then return end

            first_tx = r['txs'][1]
        else
            first_tx = r['txs'][n_tx]
        end

        first_seen = sn0int_time_from(first_tx['time'])
    end

    db_update('cryptoaddr', arg, {
        balance=r['final_balance'],
        received=r['total_received'],
        last_withdrawal=last_withdrawal,
        first_seen=first_seen,
    })
end
