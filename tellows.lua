-- Description: Query tellows.de for comments for phonenumbers
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: phonenumbers

function run(arg)
    local url = 'https://www.tellows.de/num/' .. arg['value']
    local session = http_mksession()
    local req = http_request(session, 'GET', url, {})
    local r = http_fetch(req)
    if last_err() then return end

    local caller = html_select_list(r['text'], 'label[for="callerradio-0"]')
    if #caller > 0 then
        db_update('phonenumber', arg, {
            caller_name=caller[1]['text'],
        })
    end

    local comments = html_select_list(r['text'], '.comment-body p')
    for i=1, #comments do
        local c = comments[i]['text']
        if #c > 0 then
            info(c)
        end
    end
end
