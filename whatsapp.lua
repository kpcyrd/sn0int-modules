-- Description: Fetch public profile info from whatsapp
-- Version: 0.1.0
-- Source: phonenumbers
-- License: GPL-3.0

function run(arg)
    local phonenumber = arg['value']:gsub('%W', '')
    local session = http_mksession()

    -- manually assemble the url because of &text&
    local url = 'https://api.whatsapp.com/send/?phone=' .. phonenumber .. '&text&app_absent=0'
    local req = http_request(session, 'GET', url, {})
    local r = http_fetch(req)
    if last_err() then return end

    local html = r['text']
    local main_block = html_select(html, '#main_block')
    local name_block = html_select(main_block['html'], 'h1')

    local name = name_block['text']
    debug('Main block h1 text: ' .. json_encode(name))

    -- check for placeholder `Chat auf WhatsApp mit +49 XYZ XXXXXXXX`
    -- alternatively, test if og:title content is equal to <h1> text
    if str_find(name:gsub('%W', ''), phonenumber) == nil then
        db_update('phonenumber', arg, {
            caller_name=name,
        })
    end
end
