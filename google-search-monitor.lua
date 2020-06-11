-- Description: Monitor google search results
-- Version: 0.1.0
-- License: GPL-3.0

TLD = 'com'

function run()
    local search = getopt('search')
    if not search then return '-o search= missing' end
    local session = http_mksession()

    local time = getopt('time')
    if time == 'h' then
        -- last hour
        time = 'qdr:h'
    elseif time == 'd' then
        -- last 24h
        time = 'qdr:d'
    elseif time == 'm' then
        -- last month
        time = 'qdr:m'
    else
        time = '0'
    end

    -- setup search
    -- https://github.com/MarioVilas/googlesearch/blob/a004a4f2cf465ff39f7a82f8c92f8735daab2254/googlesearch/__init__.py#L210
    local url = 'https://www.google.' .. TLD .. '/search'
    local query = {
        hl='en',
        q=search,
        -- start='0',
        tbs=time,
        safe='off',
        -- tbm='',
        -- cr='',
    }

    debug({url=url, query=query})

    local req = http_request(session, 'GET', url, {
        query=query,
    })
    local r = http_fetch(req)

    local results = html_select_list(r['text'], 'a[data-uch="1"]')
    for i=1, #results do
        local r = results[i]
        local t = html_select_list(r['html'], 'h3')
        if #t > 0 then
            t = t[1]['text']
            query = r['attrs']['href']:match('^/url%?(.+)')
            if query then
                query = url_decode(query)
                if query['q'] then
                    local href = query['q']
                    db_activity({
                        topic='kpcyrd/google-search-monitor:' .. search,
                        time=sn0int_time(),
                        uniq=href,
                        content={
                            href=href,
                            text=text,
                        },
                    })
                end
            end
        end
    end
end
