-- Description: Monitor archlinux packaging activity
-- Version: 0.1.1
-- License: GPL-3.0

function each_pkg(maintainer, pkg)
    debug(pkg)

    local version = pkg['pkgver'] .. '-' .. pkg['pkgrel']
    if pkg['epoch'] > 0 then
        version = pkg['epoch'] .. ':' .. version
    end

    local build_date = strptime('%Y-%m-%dT%H:%M:%S%.fZ', pkg['build_date'])
    local last_update = strptime('%Y-%m-%dT%H:%M:%S%.fZ', pkg['last_update'])

    local event = {
        pkgname=pkg['pkgname'],
        pkgbase=pkg['pkgbase'],
        pkgver=pkg['pkgver'],
        pkgrel=pkg['pkgrel'],
        epoch=pkg['epoch'],
        version=version,
        repo=pkg['repo'],
        arch=pkg['arch'],
        filename=pkg['filename'],
        build_date=pkg['build_date'],
        last_update=pkg['last_update'],
    }

    db_activity({
        topic='kpcyrd/archlinux-uploads:' .. maintainer .. '/build',
        time=sn0int_time_from(build_date),
        content=event,
    })
    db_activity({
        topic='kpcyrd/archlinux-uploads:' .. maintainer .. '/update',
        time=sn0int_time_from(last_update),
        content=event,
    })
end

function run()
    local maintainer = getopt('maintainer')
    if not maintainer then
        return set_err('Missing option: maintainer=')
    end

    local session = http_mksession()
    local page = 1
    while true do
        local req = http_request(session, 'GET', 'https://www.archlinux.org/packages/search/json/', {
            query={
                packager=maintainer,
                page=strval(page),
            }
        })
        local r = http_fetch_json(req)
        if last_err() then return end

        for i=1, #r['results'] do
            each_pkg(maintainer, r['results'][i])
        end

        if r['page'] < r['num_pages'] then
            page = r['page'] + 1
        else
            break
        end
    end
end
