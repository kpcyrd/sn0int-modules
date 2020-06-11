-- Description: Send a notification with pushover
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: notifications

function run(arg)
    local user_key = getopt('user_key')
    if not user_key then return '-o user_key= missing' end

    local api_token = getopt('api_token')
    if not api_token then return '-o api_token= missing' end

    --[[
    Signup for pushover and configure the app on your device.
    Copy your user key visible on the dashboard
    Click "Create an Application/API Token"
    Set "sn0int" as name and set an icon if you want to
    Copy the api token.
    ]]--

    local text = arg['subject']
    if arg['body'] then
        text = '**' .. text .. '**\n\n' .. arg['body']
    end

    -- send notification
    local session = http_mksession()
    local req = http_request(session, 'POST', 'https://api.pushover.net/1/messages.json', {
        form={
            token=api_token,
            user=user_key,
            message=text,
        }
    })
    local r = http_fetch_json(req)
    debug(r)
end
