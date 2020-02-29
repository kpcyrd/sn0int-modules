-- Description: Monitor an irc network for users
-- Version: 0.2.0
-- License: GPL-3.0

-- TODO: maybe read from accounts instead of options

function read(sock)
    while true do
        local l = sock_recvline(sock)
        if last_err() then return end

        if #l == 0 then
            return set_err('ping timeout, disconnecting')
        end
        debug(l)

        local m = regex_find('^PING (\\S+)', l)
        if m then
            debug({
                time=sn0int_time(),
                m=m
            })
            sock_sendline(sock, 'PONG ' .. m[2])
            if last_err() then return end
        else
            return l
        end
    end
end

function monitor(sock, user)
    sock_sendline(sock, 'MONITOR + ' .. user)
end

function random_name()
    while true do
        local nick = http_mksession():sub(0, 10)
        if regex_find('^[a-zA-Z]', nick) then
            return nick
        end
    end
end

function connect(sock, nick)
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

function rpl_mon(network, num, targets)
    local m = regex_find_all('([^!,]+)[^,]*', targets)

    for i=1, #m do
        local user = m[i][2]

        if num == '730' then
            push_event(network, user, 'online')
        elseif num == '731' then
            push_event(network, user, 'offline')
        end
    end
end

function push_event(network, user, state)
    local now = sn0int_time()
    info(now .. ' ' .. state .. ': ' .. user)

    local topic = 'kpcyrd/irc-monitor:' .. network .. '/' .. user
    db_activity({
        topic=topic,
        time=now,
        content={
            state=state,
        }
    })
end

function run(arg)
    local network = getopt('network')
    if not network then
        return 'Missing network= option (irc.example.com)'
    end
    local port = intval(getopt('port') or 6697)
    local tls = not getopt('insecure')
    local target = getopt('target')
    if not target then
        return 'Missing target= option (user1,user2)'
    end
    local nick = getopt('nick') or random_name()
    local ping_timeout = intval(getopt('ping_timeout') or 240)

    local sock = sock_connect(network, port, {
        tls=tls,
        read_timeout=ping_timeout,
    })

    connect(sock, nick)
    if last_err() then return end

    monitor(sock, target)
    if last_err() then return end

    while true do
        local l = read(sock)
        if last_err() then return end

        local m = regex_find('^(\\S+) (\\S+) (\\S+) :(\\S+)', l)
        if m then
            rpl_mon(network, m[3], m[5])
        end
    end
end
