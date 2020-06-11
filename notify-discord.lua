-- Description: Send a notification with discord
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: notifications

function run(arg)
    local url = getopt('url')
    if not url then return '-o url= missing' end

    --[[
    Decide which channel should receive notifications (or create a new one)
    Open the "Server Settings" of your discord server
    Click on "Webhooks"
    Click "Create Webhook"
    Configure the Name and Channel
    Copy the Webhook URL
    ]]--

    local text = arg['subject']
    if arg['body'] then
        text = '**' .. text .. '**\n\n' .. arg['body']
    end

    local session = http_mksession()
    local req = http_request(session, 'POST', url, {
        json={
            content=text,
        },
    })
    local r = http_fetch(req)
    debug(r)
end
