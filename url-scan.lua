-- Description: Scan subdomains for websites
-- Version: 0.5.3
-- Source: subdomains
-- License: GPL-3.0

function add_port(subdomain_id, ip_addr, port, r)
    ip_addr_id = db_add('ipaddr', {
        value=ip_addr,
    })
    if not ip_addr_id then return end

    db_add('subdomain-ipaddr', {
        subdomain_id=subdomain_id,
        ip_addr_id=ip_addr_id,
    })

    db_add('port', {
        ip_addr_id=ip_addr_id,
        ip_addr=ip_addr,
        port=port,
        protocol='tcp',
        status='open',
        banner=r['headers']['server'],
    })
end

function request(subdomain, url, port)
    local req = http_request(session, 'GET', url, {
        timeout=3000,
        binary=true,
    })
    local r = http_send(req)

    if last_err() then
        return clear_err()
    end

    db_update('subdomain', subdomain, {
        resolvable=true,
    })

    if r['ipaddr'] then
        add_port(subdomain['id'], r['ipaddr'], port, r)
    end

    -- an empty sequence is detected as a map and causing deserialization issues
    -- force an empty string in that case
    if #r['binary'] == 0 then
        r['binary'] = ''
    end

    db_add('url', {
        subdomain_id=subdomain['id'],
        value=url,
        status=r['status'],
        body=r['binary'],
        redirect=r['headers']['location'],
        online=true,
    })
end

function run(arg)
    local domain = arg['value']

    session = http_mksession()
    request(arg, 'http://' .. domain .. '/', 80)
    if last_err() then return end
    request(arg, 'https://' .. domain .. '/', 443)
    if last_err() then return end
end
