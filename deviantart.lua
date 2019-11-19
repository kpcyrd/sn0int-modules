-- Description: Collect data and images from deviantart profiles
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: accounts:deviantart.com

function grab_post(url)
    debug('fetching ' .. url)
    local post_date = nil

    local req = http_request(session, 'GET', url, {})
    local r = http_fetch(req)
    if last_err() then return end

    local spans = html_select_list(r['text'], '[data-hook="deviation_meta"] span')
    for i=1, #spans do
        local m = regex_find('Published: (.+)', spans[i]['text'])
        if m then
            post_date = strptime('%B %d, %Y %H:%M:%S', m[2] .. ' 00:00:00')
            if last_err() then return end
        end
    end

    local download = html_select(r['text'], 'a[aria-label="Download"]')
    if last_err() then return end
    download = download['attrs']['href']

    req = http_request(session, 'GET', download, {})
    r = http_send(req)
    if last_err() then return end
    if r['status'] ~= 302 then
        -- TODO: set_err
        return
    end
    download = r['headers']['location']

    req = http_request(session, 'GET', download, {
        into_blob=true,
    })
    r = http_fetch(req)
    if last_err() then return end

    db_add('image', {
        value=r['blob'],
    })

    return post_date
end

function cmp_last_seen(a, b)
    if a == nil and b == nil then
        return nil
    end

    if a ~= nil and b == nil then
        return a
    end

    if a == nil and b ~= nil then
        return b
    end

    if a > b then
        return a
    else
        return b
    end
end

function run(arg)
    local update = {}
    local url = 'https://www.deviantart.com/' .. arg['username']
    update['url'] = url

    -- birthday (possibly no year)
    -- location (free style text)

    session = http_mksession()
    local req = http_request(session, 'GET', url .. '/about', {})
    local r = http_fetch(req)
    if last_err() then return end

    local comments = html_select_list(r['text'], '#my_comments time')
    if #comments > 1 then
        local last_activity = comments[1]['attrs']['datetime']
        -- convert to timestamp
        update['last_seen'] = strptime('%Y-%m-%dT%H:%M:%S.000Z', last_activity)
        if last_err() then return end
    end

    req = http_request(session, 'GET', url .. '/gallery/all', {})
    r = http_fetch(req)
    if last_err() then return end

    local posts = html_select_list(r['text'], '[id="-1"] a[data-hook="deviation_link"]')
    for i=1, #posts do
        local post_date = grab_post(posts[i]['attrs']['href'])
        local err = last_err()

        if err then
            warn(err)
            clear_err()
        else
            update['last_seen'] = cmp_last_seen(update['last_seen'], post_date)
        end
    end

    -- normalize timestamp
    if update['last_seen'] ~= nil then
        update['last_seen'] = strftime('%Y-%m-%dT%H:%M:%S', update['last_seen'])
    end

    info(update)
end
