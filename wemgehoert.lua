-- Description: Query wemgehoert.de for comments for phonenumbers
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: phonenumbers

function run(arg)
    local url = 'https://www.wemgehoert.de/nummer/' .. str_replace(arg['value'], '+', '')
    local session = http_mksession()
    local req = http_request(session, 'GET', url, {})
    local r = http_fetch(req)
    if last_err() then return end

    -- exit if there are no comments
    local num = html_select(r['text'], '#count-comments')
    if num['text'] == '0' then return end

    local cs = html_select_list(r['text'], '.comment-text')
    for i=1, #cs do
        info(cs[i]['text'])
    end
end
