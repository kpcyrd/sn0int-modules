-- Description: Monitor irc channels for messages
-- Version: 0.1.0
-- License: GPL-3.0

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

function activity(network, content)
    local topic = 'kpcyrd/irc-logger:' .. network .. '/' .. content['channel']

    if content['nick'] then
        topic = topic .. '/' .. content['nick']
    end

    db_activity({
        topic=topic,
        time=sn0int_time(),
        content=content,
    })
end

function run()
    local network = getopt('network')
    if not network then
        return 'Missing network= option (irc.example.com)'
    end
    local port = getopt('port')
    if not port then
        port = '6697'
    end
    local tls = not getopt('insecure')
    local channels = getopt('channels')
    if not channels then
        return 'Missing channels= option (#channel1,#channel2)'
    end
    local nick = getopt('nick')
    if not nick then
        nick = random_name()
    end

    local sock = sock_connect(network, intval(port), {
        tls=tls,
    })

    connect(sock, nick)
    if last_err() then return end

    local m = regex_find_all('[^,]+', channels)
    for i=1, #m do
        local channel = m[i][1]
        debug('joining ' .. channel)
        sock_sendline(sock, 'JOIN ' .. channel)
    end

    while true do
        local l = read(sock)
        if last_err() then return end

        local m = regex_find('^:(([^!]+)[^ ]+) PRIVMSG ([^ ]+) :([^\r]+)', l)
        if m then
            activity(network, {
                t='msg',
                nick=m[3],
                fulluser=m[2],
                channel=m[4],
                msg=m[5],
            })
        end

        local m = regex_find('^:(([^!]+)[^ ]+) (JOIN|PART) ([^\r]+)', l)
        if m then
            activity(network, {
                t=m[4]:lower(),
                nick=m[3],
                fulluser=m[2],
                channel=m[5],
            })
        end

        local m = regex_find('^\\S+ 332 \\S+ (\\S+) :([^\r]+)', l)
        if m then
            activity(network, {
                t='topic',
                channel=m[2],
                topic=m[3],
            })
        end

        local m = regex_find('^:(([^!]+)[^ ]+) TOPIC ([^ ]+) :([^\r]+)', l)
        if m then
            activity(network, {
                t='topic',
                nick=m[3],
                fulluser=m[2],
                channel=m[4],
                topic=m[5],
            })
        end

        local m = regex_find('^\\S+ 353 \\S+ . (\\S+) :([^\r]+)', l)
        if m then
            local channel = m[2]
            local m = regex_find_all('[^ @\\+~]+', m[3])
            for i=1, #m do
                activity(network, {
                    t='online',
                    channel=channel,
                    nick=m[i][1]
                })
            end
        end
    end
end
