-- Description: Collect information about an archive.org profile
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: accounts:archive.org

function read_activity(user, item)
    local added_date = strptime('%Y-%m-%dT%H:%M:%SZ', item['fields']['addeddate'])
    local identifier = item['fields']['identifier']

    -- fetch metadata item
    local url ='https://archive.org/download/' .. identifier .. '/' .. identifier .. '_meta.xml'
    local req = http_request(session, 'GET', url, {
        follow_redirects=5,
    })
    local r = http_fetch(req)
    if last_err() then return end

    local xml = xml_decode(r['text'])
    if last_err() then return end

    -- populate the base activity content
    local content = {
        title=item['fields']['title'],
        description=item['fields']['description'],
        files_count=item['fields']['files_count'],
        item_size=item['fields']['item_size'],
    }

    -- conditionally extend the content
    local uploader = xml_named(xml['children'][1], 'uploader')
    if uploader then
        content['uploader'] = uploader['text']
        local m = regex_find('^([^@]+)@([^@]+)$', uploader['text'])
        if m then
            db_add('email', {
                value=m[1],
            })
        end
    end

    -- insert the event
    debug({identifier=identifier, content=content})
    db_activity({
        topic='kpcyrd/archive-org:' .. user,
        time=sn0int_time_from(added_date),
        uniq='added:' .. identifier,
        content=content,
    })
end

function run(arg)
    local user = arg['username']
    local page = 1

    session = http_mksession()
    while true do
        debug('page=' .. page)
        local req = http_request(session, 'GET', 'https://archive.org/services/search/beta/page_production/', {
            query={
                user_query='',
                page_type='account_details',
                page_target='@' .. user,
                page_elements='["uploads"]',
                hits_per_page='100',
                page=strval(page),
                sort='publicdate:desc',
                aggregations='false',
                client_url=url_escape('https://archive.org/details/@' .. user),
            }
        })
        local r = http_fetch_json(req)
        if last_err() then return end

        if not r['response']['header']['succeeded'] then
            return set_err('Received an api error, `succeeded` not true')
        end

        if page == 1 then
            info('Registered since: ' .. r['response']['body']['account_extra_info']['account_details']['user_since'])
        end
        local items = r['response']['body']['page_elements']['uploads']['hits']['hits']

        if #items == 0 then
            break
        end

        for i=1, #items do
            read_activity(user, items[i])
            if last_err() then return end
        end

        page = page + 1
    end
end
