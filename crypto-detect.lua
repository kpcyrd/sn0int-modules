-- Description: Detect crypto currency from address
-- Version: 0.2.0
-- License: GPL-3.0
-- Source: cryptoaddrs

function run(arg)
    -- btc
    m = regex_find('^(bc1|[13])[a-zA-HJ-NP-Z0-9]{25,39}$', arg['value'])
    if m then
        db_update('cryptoaddr', arg, {
            currency='btc',
            denominator=8,
        })
    end

    -- xmr
    m = regex_find('^4[0-9AB][1-9A-HJ-NP-Za-km-z]{93}$', arg['value'])
    if m then
        db_update('cryptoaddr', arg, {
            currency='xmr',
            denominator=12,
        })
    end

    -- zec
    -- TODO: improve regex
    m = regex_find('^t[13][a-zA-Z0-9]{33}$', arg['value'])
    if m then
        db_update('cryptoaddr', arg, {
            currency='zec',
            denominator=8,
        })
    end

    -- eth
    m = regex_find('^0x[a-fA-F0-9]{40}$', arg['value'])
    if m then
        db_update('cryptoaddr', arg, {
            currency='eth',
            denominator=18,
        })
    end

    -- doge
    m = regex_find('^D{1}[5-9A-HJ-NP-U]{1}[1-9A-HJ-NP-Za-km-z]{32}$', arg['value'])
    if m then
        db_update('cryptoaddr', arg, {
            currency='doge',
            denominator=8,
        })
    end
end
