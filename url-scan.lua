-- Description: Scan subdomains for websites
-- Version: 0.5.0
-- Source: subdomains
-- License: GPL-3.0

function add_port(ip_addr, port, r)
    ip_addr_id = db_add('ipaddr', {
        value=ip_addr,
    })
    if not ip_addr_id then return end

    db_add('port', {
        ip_addr_id=ip_addr_id,
        ip_addr=ip_addr,
        port=port,
        protocol='tcp',
        status='open',
        banner=r['headers']['server'],
    })
end

function request(subdomain_id, url, port)
    local req = http_request(session, 'GET', url, {
        timeout=5000,
        binary=true,
    })
    local r = http_send(req)

    if last_err() then
        return clear_err()
    end

    if r['ipaddr'] then
        add_port(r['ipaddr'], port, r)
    end

    db_add('url', {
        subdomain_id=subdomain_id,
        value=url,
        status=r['status'],
        body=r['binary'],
        redirect=r['headers']['location'],
    })
end

function run(arg)
    local domain = arg['value']

    session = http_mksession()
    request(arg['id'], 'http://' .. domain .. '/', 80)
    if last_err() then return end
    request(arg['id'], 'https://' .. domain .. '/', 443)
    if last_err() then return end
end
