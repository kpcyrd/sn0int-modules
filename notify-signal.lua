-- Description: Send a notification with signal
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: notifications

function run(arg)
    local secret = getopt('secret')
    if not secret then return '-o secret= missing' end
    local to = getopt('to')
    if not secret then return '-o to= missing' end
    local url = getopt('url')
    if not url then
        url = 'http://127.0.0.1:4321/api/v0/send'
    end

    --[[
    This end-to-end encrypts notifications with signal.
    The setup for this is slightly more elaborate.
    See https://github.com/kpcyrd/sn0int-signal
    Important: it's recommended to set the url explicitly
    ]]--

    local text = arg['subject']
    if arg['body'] then
        text = '**' .. text .. '**\n\n' .. arg['body']
    end

    local session = http_mksession()
    local headers = {}
    headers['x-signal-auth'] = secret
    local req = http_request(session, 'POST', url, {
        headers=headers,
        json={
            to=to,
            body=text,
        },
    })
    local r = http_fetch(req)
    debug(r)
end
