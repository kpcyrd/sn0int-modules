-- Description: TODO your description here
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: urls

function parse_url(url)
    local parts = url_parse(url)
    if last_err() then return clear_err() end
    debug(parts)

    local host = parts['host']
    local path = parts['path']
    local params = parts['params']

    if host == 'www.google.com' and path == '/maps/embed' and params then
        local pb = params['pb']

        local m = regex_find('!3d([^!]+)', pb)
        if not m then return end
        local lat = m[2]

        local m = regex_find('!2d([^!]+)', pb)
        if not m then return end
        local lon = m[2]

        info({google={lat=lat, lon=lon}})
    end

    if host == 'www.openstreetmap.org' and params and params['mlat'] and params['mlon'] then
        info({osm={lat=params['mlat'], lon=params['mlon']}})
    end
end

function run(arg)
    local body = arg['body']

    if not body then
        -- TODO: if body is set use that instead
        local session = http_mksession()
        local req = http_request(session, 'GET', arg['value'], {})
        local r = http_send(req)

        -- TODO this doesn't work yet
        --[[
        db_update('url', arg, {
            status=r['status'],
            body=r['text'],
        })
        ]]--

        if r['status'] ~= 200 then
            return
        end
        body = r['text']
    end

    local iframes = html_select_list(body, 'iframe')
    for i=1, #iframes do
        local src = iframes[i]['attrs']['src']
        debug(src)
        if src then
            parse_url(src)
            if last_err() then return end
        end
    end

    local links = html_select_list(body, 'a')
    for i=1, #links do
        local href = links[i]['attrs']['href']
        debug(href)
        if href then
            parse_url(href)
            if last_err() then return end
        end
    end
end
