-- Description: Monitor an irc network for users
-- Version: 0.1.0
-- License: GPL-3.0

-- TODO: maybe read from accounts instead of options

function read(sock)
    while true do
        local l = sock_recvline(sock)
        if last_err() then return end
        debug(l)

        local m = regex_find('^PING (\\S+)', l)
        if m then
            sock_sendline(sock, 'PONG ' .. m[2])
            if last_err() then return end
            debug(m)
        else
            return l
        end
    end
end

function monitor(sock, user)
    sock_sendline(sock, 'MONITOR + ' .. user)
end

function random_name()
    return http_mksession():sub(0, 10)
end

function connect(sock)
    local nick = random_name()
    sock_sendline(sock, 'NICK ' .. nick)
    sock_sendline(sock, 'USER ' .. nick .. ' 8 x : ' .. nick)
    if last_err() then return end

    while true do
        local l = read(sock)
        if last_err() then return end

        local m = regex_find('^(\\S+) (\\S+)', l)
        if m then
            -- TODO: maybe wait for m[2] == 'MODE' instead
            if m[3] == '376' then
                debug('successfully connected')
                return
            end
        end
    end
end

function rpl_mon(num, targets)
    local m = regex_find_all('([^!,]+)[^,]*', targets)
    local now = sn0int_time()

    for i=1, #m do
        local user = m[i][2]
        if num == '730' then
            info(now .. ' online: ' .. user)
        elseif num == '731' then
            info(now .. ' offline: ' .. user)
        end
    end
end

function run(arg)
    local network = getopt('network')
    if not network then
        return 'Missing network= option (irc.example.com)'
    end
    local port = getopt('port')
    if not port then
        port = '6697'
    end
    local tls = not getopt('insecure')
    local target = getopt('target')
    if not target then
        return 'Missing target= option (user1,user2)'
    end

    local sock = sock_connect(network, intval(port), {
        tls=tls,
    })

    connect(sock)
    if last_err() then return end

    monitor(sock, target)
    if last_err() then return end

    while true do
        local l = read(sock)
        if last_err() then return end

        local m = regex_find('^(\\S+) (\\S+) (\\S+) :(\\S+)', l)
        if m then
            rpl_mon(m[3], m[5])
        end
    end
end
