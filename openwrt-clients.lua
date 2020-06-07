-- Description: Monitor luci ubus for connected wifi clients
-- Version: 0.1.0
-- License: GPL-3.0

function get_wifis(router, sysauth)
    local url = url_join(router, '/cgi-bin/luci/admin/ubus')
    local req = http_request(session, 'POST', url, {
        json={
            {jsonrpc='2.0', id=1, method='call', params={sysauth, 'luci-rpc', 'getWirelessDevices', {}}},
        },
    })
    local r = http_fetch_json(req)
    if last_err() then return end

    local wifis = {}

    local interfaces = r[1]['result'][2]['radio0']['interfaces']
    for i=1, #interfaces do
        wifis[#wifis+1] = {
            name=interfaces[i]['ifname'],
            ssid=interfaces[i]['config']['ssid'],
        }
    end

    return wifis
end

function build_hostname_map(dhcp)
    local r = dhcp['result'][2]

    local hosts = {}

    local v4 = r['dhcp_leases']
    for i=1, #v4 do
        local l = r['dhcp_leases'][i]
        local mac = l['macaddr']
        if not hosts[mac] then
            hosts[mac] = {
                ipaddr=l['ipaddr'],
                hostname=l['hostname'],
            }
        end
    end

    local v6 = r['dhcp6_leases']
    for i=1, #v6 do
        local l = r['dhcp_leases'][i]
        local mac = l['macaddr']
        if not hosts[mac] then
            hosts[mac] = {
                ipaddr=l['ip6addr'], -- technically there are multiple we know about
                hostname=l['hostname'],
            }
        end
    end

    return hosts
end

function fetch_clients(router, sysauth, wifis)
    local json = {
        {jsonrpc='2.0', id=1337, method='call', params={sysauth, 'luci-rpc', 'getDHCPLeases', {}}},
    }

    for i=1, #wifis do
        local device = wifis[i]['name']
        json[#json+1] = {jsonrpc='2.0', id=1337, method='call', params={sysauth, 'iwinfo', 'assoclist', {device=device}}}
    end

    local url = url_join(router, '/cgi-bin/luci/admin/ubus')
    local req = http_request(session, 'POST', url, {
        json=json,
    })
    local r = http_fetch_json(req)
    if last_err() then return end

    local hostnames = build_hostname_map(r[1])
    for i=2, #r do
        assoclist(r[i], wifis[i-1]['ssid'], hostnames)
    end
end

function assoclist(r, ssid, hostnames)
    local network_id = db_add('network', {
        value=ssid,
    })

    local r = r['result'][2]['results']
    for i=1, #r do
        local client = r[i]
        local mac = r[i]['mac']:lower()
        local hostname = nil
        local ipaddr = nil

        local h = hostnames[mac]
        if h then
            hostname = h['hostname']
            ipaddr = h['ipaddr']
        end

        local client = {
            ssid=ssid,
            mac=mac,
            hostname=hostname,
            ipaddr=ipaddr,
            signal=r[i]['signal'],
            noise=r[i]['noise'],
        }
        debug(client)

        -- TODO: first_seen
        local now = sn0int_time()

        local device_id = db_add('device', {
            value=mac,
            hostname=hostname,
            last_seen=now,
        })

        if network_id and device_id then
            db_add_ttl('network-device', {
                network_id=network_id,
                device_id=device_id,
                ipaddr=ipaddr,
                last_seen=now,
            }, 300)
        end

        local topic = 'kpcyrd/openwrt-clients:' .. ssid .. '/' .. mac
        db_activity({
            topic=topic,
            time=now,
            content={
                client=client,
            }
        })
    end
end

function run()
    session = http_mksession()

    local router = getopt('router') -- http://192.0.2.1/
    if not router then
        return 'router option is missing (http://192.0.2.1/)'
    end

    local user = getopt('user')
    if not user then
        return 'user option is missing'
    end
    local password = getopt('password')
    if not password then
        return 'password option is missing'
    end
    local monitor_interval = getopt('monitor-interval')
    if monitor_interval then
        monitor_interval = intval(monitor_interval)
    end

    -- login
    local url = url_join(router, '/cgi-bin/luci')
    local req = http_request(session, 'POST', url, {
        form={
            luci_username=user,
            luci_password=password,
        }
    })

    local r = http_send(req)
    if last_err() then return end
    if r['status'] ~= 302 then
        return 'login failed'
    end

    -- get cookie
    req = http_request(session, 'GET', router, {})
    local sysauth = req['cookies']['sysauth']

    -- fetch clients on all networks
    local wifis = get_wifis(router, sysauth)
    while true do
        fetch_clients(router, sysauth, wifis)
        if not monitor_interval then
            break
        end
        sleep(monitor_interval)
    end
end
