-- Description: Import domains and subdomains from SAN certificates
-- Version: 0.2.0
-- License: GPL-3.0
-- Source: subdomains

function each_name(name)
    domain = psl_domain_from_dns_name(name)
    if last_err() then return end

    domain_id = db_add('domain', {
        value=domain,
    })

    if name:find('*.') == 1 then
        -- ignore wildcard domains
        return
    end

    db_add('subdomain', {
        domain_id=domain_id,
        value=name,
    })
end

function run(arg)
    local port = intval(getopt('port')) or 443
    local sock = sock_connect(arg['value'], port, {
        connect_timeout=5,
        read_timeout=5,
        write_timeout=5,
    })
    if last_err() then return end

    local tls = sock_upgrade_tls(sock, {
        sni_value=arg['value'],
        disable_tls_verify=true,
    })
    if last_err() then return end

    local cert = x509_parse_pem(tls['cert'])
    for i=1, #cert['valid_names'] do
        local name = cert['valid_names'][i]
        each_name(name)
    end
end
