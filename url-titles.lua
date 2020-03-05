-- Description: Scan cached http responses for html titles
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: urls

function run(arg)
    local body = utf8_decode(arg['body'])
    if last_err() then return clear_err() end

    local title = html_select(body, 'title')
    if last_err() then return clear_err() end

    local m = regex_find('^\\s*(.+)\\s*$', title['text'])
    if m then
        db_update('url', arg, {
            title=m[2],
        })
    end
end
