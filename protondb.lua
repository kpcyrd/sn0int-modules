-- Description: Collect system information and steam handles from protondb profiles
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: accounts:protondb.com

function find_steam_account(name)
    -- populate cookie jar
    local req = http_request(session, 'GET', 'https://steamcommunity.com/search/users/', {})
    local r = http_fetch(req)
    if last_err() then return end
    req = http_request(session, 'GET', 'https://steamcommunity.com/search/users/', {})
    local sid = req['cookies']['sessionid']

    req = http_request(session, 'GET', 'https://steamcommunity.com/search/SearchCommunityAjax', {
        query={
            text=name,
            filter='users',
            sessionid=sid,
            steamid_user='false',
            page='1',
        }
    })
    r = http_fetch_json(req)
    if last_err() then return end

    if r['success'] == 1 and r['search_result_count'] == 1 then
        local link = html_select(r['html'], 'a.searchPersonaName')
        if link['text'] ~= name then return end

        local m = regex_find('https://steamcommunity.com/.+/(.+)', link['attrs']['href'])
        db_add('account', {
            service='steamcommunity.com',
            username=m[2],
            displayname=name,
        })
    end
end

function run(arg)
    session = http_mksession()
    local req = http_request(session, 'GET', 'https://www.protondb.com/data/users/by_id/' .. arg['username'] .. '.json', {})
    local r = http_fetch_json(req)
    if last_err() then return end

    local last_seen = 0
    for i=1, #r['reports'] do
        local report = r['reports'][i]

        if last_seen < report['timestamp'] then
            last_seen = report['timestamp']
        end

        local keys = {'os', 'kernel', 'cpu', 'gpu', 'gpuDriver', 'ram'}
        for j=1, #keys do
            info(report['app']['title'] .. ' - ' .. keys[j] .. ': ' .. report['systemInfo']['inferred'][keys[j]])
        end
    end

    if last_seen > 0 then
        last_seen = sn0int_time_from(last_seen)
    else 
        last_seen = nil
    end

    -- info(r['steam']['avatar'])
    db_update('account', arg, {
        displayname=r['steam']['nickname'],
        last_seen=last_seen,
    })

    find_steam_account(r['steam']['nickname'])
end
