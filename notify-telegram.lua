-- Description: Send a notification with telegram
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: notifications

function run(arg)
    local bot_token = getopt('bot_token')
    if not bot_token then return '-o bot_token= missing' end
    local chat_id = intval(getopt('chat_id'))
    if not chat_id then return '-o chat_id= missing' end

    --[[
    Message @botfather on telegram to get a bot_token.
    Afterwards, send /start to your new bot
    Open https://api.telegram.org/bot**your_bot_token**/getUpdates
    Find your chat_id
    ]]--

    local url = 'https://api.telegram.org/bot' .. bot_token .. '/sendMessage'

    local text = arg['subject']
    if arg['body'] then
        text = '**' .. text .. '**\n\n' .. arg['body']
    end

    -- send notification
    local session = http_mksession()
    local req = http_request(session, 'POST', url, {
        json={
            text=text,
            chat_id=chat_id,
            -- parse_mode='HTML',
        },
    })
    local r = http_fetch_json(req)
    debug(r)
end
