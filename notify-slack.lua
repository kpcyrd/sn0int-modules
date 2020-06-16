-- Description: Send a notification with slack
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: notifications

function run(arg)
    local url = getopt('url')
    if not url then return '-o url= missing' end

    local text = arg['subject']
    if arg['body'] then
        text = '**' .. text .. '**\n\n' .. arg['body']
    end

    -- send notification
    local session = http_mksession()
    local req = http_request(session, 'POST', url, {
        json={
            text=text,
        }
    })
    local r = http_fetch(req)
    debug(r)
end
