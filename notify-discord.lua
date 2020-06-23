-- Description: Send a notification with discord
-- Version: 0.1.2
-- License: GPL-3.0
-- Source: notifications

function run(arg)
    local url = getopt('url')
    if not url then return '-o url= missing' end

    -- TODO: we can't properly implement discord ratelimits without a global state that tracks info from the last request
    -- TODO: if this module fails, the message should be queued for retry in a way that we're able to honor ratelimits properly
    -- TODO: reduce the delay again after retries are in place
    ratelimit_throttle('notify-discord-webhooks', 1, 2500)

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
