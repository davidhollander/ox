--ox.lua
--David Hollander Feb 2011
--license: LGPL

--Modules
local nixio=require'nixio',require'nixio.util'
local lhp=require'http.parser'
local json=require'json'
local bcheck=nixio.bit.check
module('ox',package.seeall)

--Builtins
local workers, sessions, threads={},{},{}
local status={}
local HTTP={GET={},POST={},PUT={}}
local RPC={GET={},POST={},PUT={}}
status[200]='HTTP/1.1 200 OK\r\n\r\n'
status[404]='HTTP/1.1 404 Not Found\r\n\r\n'

--Sessions
setcookie=function(client)
    local key=string.format('%x',math.random(10e10))
    sessions[key]=client.fd:getpeername()
    print('setcookie',key,sessions[key])
    return table.concat{
        'Set-cookie: u=',key,'; httponly',
        '\r\n'}
end
--Helpers
local reqparser=function(req) return
    lhp.request{
        on_url=function(url) req.url=url end,
        on_path=function(path) req.path=path end,
        on_header=function(key,val) req.headers[key]=val end,
        on_query_string=function(qstr) req.qstr=qstr end,
        on_fragment=function(frag) req.frag=frag end,
        on_body=function(body) req.body=body end,
        --on_message_begin=print,
        on_message_complete=function() req.parsed=true end,
        --on_headers_complete=print,
    }
end
local resparser=function(res) return
    lhp.response{
        on_header=function(key,val) res.headers[key]=val end
        on_body=function(body) req.body=body end,
        on_message_complete=function() req.parsed=true end,
    }
end
makecounter=function()
    local i=0
    return function(n)
        if n then i=i+n end
        return i
    end
end
--[[
acceptrpc=function(server)
    print('acceptworker')
    server.revents=0
    while true do
        local sock=server.fd:accept()
        if sock then
            sock:setblocking(fase)
            table.insert(threads,{
                fd=sock,
                events=nixio.poll_flags('in'),
                revents=0,
                buffer='',
                read=readmsg,
                send=sendmsg,
                close=closeworker})
        else break
        end
    end
end]]
--[[
sendmsg=function(i,conn)
--Todo: Remove worker if erorr on write
    print('sendjob')
    if not conn.bytessent then conn.bytessent=makecounter() end
    local n=conn.bytessent(
        conn.fd:send(conn.out,conn.bytessent()))
    print('msgbytessent',n,conn.out)
    if n>=#conn.out then
        conn.out=nil
        conn.bytessent=nil
        conn.events=nixio.poll_flags('in') --cycle back to reading
        conn.f=readmsg
    end
end]]
--[[
readhttps=function(client)
--idea\not implemented.
--would need to create TLS context and then wrap socket into a TLS socket
    tls=nixio.tls('server')
    tls:create(client.fd)
end
closeworker=function(worker)
    --Remove disconnected worker from its jobs
    for i,j in conn.jobs do
        for i,w in ipairs(j.workers) do
            if w==conn then table.remove(j.workers,i) end
        end
        if #j.workers==0 then table.remove(jobs,i) end
    end
    conn.fd:close()
    return 'close'
end
readworker=function(worker)
    print('readmsg')
    local data=conn.fd:recv(1024)
    if data==false then return true
    elseif data==nil or data=='' then return false end
    conn.rbuffer=conn.rbuffer..data
    local job, msg, part=conn.buffer:match('^{%%([^:]+):(.*)%%}(.*)')
    print(job,msg,part)
    if job then
        conn.rbuffer=part
        if methods[job] then
            local out=jobs[job](conn,msg) --If method returns then respond
            if out then
                conn.out=out
                conn.events=nixio.poll_flags('out')
                conn.f=sendmsg
            end
        else print("Job does not exist: ",job) end
    end
end]]
--[[
connect=function(host,port)
    local conn=nixio.connect(host,port)
    assert(conn,'Could not connect to '..host..':'..port)
    print('connected to ',host,port)
    conn:setblocking(false)
    table.insert(threads,{
        fd=conn,
        events=nixio.poll_flags('out'),
        revents=0,
        bytessent=makecounter(),
        buffer='',
        out=register_str,
        read=readmsg,
        send=sendmsg,
        close=closeconn})
end]]

--Handle HTTP
readcookie=function(client)
    local v=client.req.headers.Cookie
    print('readcookie',v,sessions[v])
    if v and sessions[v:match('u=(%x+)')]==client.fd:getpeername() then
        client.req.user=true
    end
end

--Send
sendhttp=function(client)
    print('sendhttp')
    if not client.bytessent then client.bytessent=makecounter() end
    local c=client.bytessent
    c(client.fd:send(client.out,c()))
    if c()>=#client.out then return 'close' end
end
--Close
closehttp=function(client)
    print('closehttp')
    client.fd:close()
end
--Read
readhttp=function(client)
    print('readhttp')
    local data=client.fd:recv(1024)
    if data==false then return 
    elseif data==nil or data=='' then return 'close'
    elseif client.parser:execute(data)>0 and client.req.parsed then
        readcookie(client)
        local found=false
        print('Views: ',client.server.views,client.parser:method())
        for p,f in pairs(client.server.views[client.parser:method()]) do
            local capture=client.req.path:match(p)
            print(capture)
            if capture then f(client,capture) found=true break end
        end
        if not found then client.out=status[404] client.events=nixio.poll_flags('out')
        end
    end
end
readres=function(server)
    print('readres')
    local data=client.fd:recv(8192)
    if data==false then return
    elseif data==nil or data=='' then return 'close'
    elseif client.parser:execute(data)>0 and client.req.parsed then
end
--Accept
accepthttp=function(server)
    print('accepthttp')
    server.revents=0
    while true do
        local sock=server.fd:accept()
        print('accepted',sock)
        print('closehttp: ',closehttp)
        if sock then 
            sock:setblocking(false)
            local req={headers={}}
            table.insert(threads,{
                fd=sock,
                server=server,
                events=nixio.poll_flags('in'),
                revents=0,
                req=req,
                timestamp=os.time(),
                parser=reqparser(req),
                read=readhttp,
                close=closehttp,
                send=sendhttp})
        else break
        end
    end
end
Get('http','google.com',{['content-type']="rofl"},
    function(body)
        print(body) end)
Put('rpc','127.0.0.1',{},
    function(status)
        print(status) end)
HTTP.GET['/blog']=function(client)
    Connect('http','google.com'
        function(server)
            sendbuffer(server,req)
            readbuffer(server,function(res)
                sendbuffer(client,res)
            end)
        end)
    end

SetEvent=function(thread,ev,cb)
    nixio.bit.set(thread.events,poll_flags(ev))
    thread[ev]=cb
end
ClearEvent=function(thread,ev)
    nixio.bit.unset(thread.events,poll_flags(ev))
    thread[ev]=nil
end
ChainEvents=function(set,cb)
    local nready=0
    cb2=function
    for i=1,#set,2 do
        setevent(set[i],set[i+1])
SendAll=function(thread,msg)
    SetEvent(thread,out,
        function(msg)
            local n=0
            return function(thread)
                n=thread.fd:send(msg,n)
                if n>=#msg then ClearEvent(thread,out) end
            end
        end
    )
end
Pump=function(threadout,threadin)
    threadout
end
HTTP.GET['/blog']=function(client)
    Connect('127.0.0.1',8081,
        function(server)
            SendAll(server,'GET post1\n')
            ReadAll(server,
                function(response)
                    Close(server)
                    SendAll(client,response,call(Close,client))
                end
            )
        end
    )
end


HTTP.GET['/blog']=function(client)
    Connect('http://google.com',80,
        function(server)
            SendAll(server,'GET / HTTP/1.1\r\n\r\n')
            Pump(client,server)
            

            ChainEvents({client,'out',server,'in'},
                doubleready=function()
                    cycle(client,server)
                clientready=function()
                    flushclient()
                (function()
                    local n=0
                    local msg=''
                    return function(client,server)
                        if not msg then msg=server.fd:read(8192) end
                        n=client.fd:send(msg,n)
                        if n==#msg then msg=false end

                    end
                end)()

Get()
GetChunks()
Respond()
RespondChunks()
Put()
PutChunks()
Post()
PostChunks()

function HTTPGet(host,url,params,cb)
    local req={'GET ',url,' HTTP/1.1\r\n\r\n'}
    local conn=nixio.connect(host,80)
    if conn then
        conn:setblocking(false)
        table.insert(threads,{
            fd=conn,
            events=nixio.poll_flags('out'),
            revents=0,
            bytessent=makecounter(),
            out=table.concat(req),
            read=readhttpres,
            send=sendhttpreq,
            parser=resparser(res),
            close=closehttp
        })
        return true
    else return false end
end

--Bind
httpserver=function(port,views)
  local server=nixio.bind('*',port)
  assert(server,'Could not bind to '..port)
  print('server on '..port)
  server:setblocking(false)
  server:listen(100)
  table.insert(threads,{
    views=views,
    fd=server,
    events=nixio.poll_flags('in'),
    revents=0,
    close=print,
    read=accepthttp})
end
rpcserver=function(port,views)
    assert(false,'not implemented')
end

connect=function(host,port)
    local conn=nixio.connect(host,port)
    assert(conn,'Could not connect to '..host..':'..port)
    print('connected to ',host,port)
    conn:setblocking(false)
    table.insert(threads,{
        fd=conn,
        events=nixio.poll_flags('out'),
        revents=0,
        bytessent=makecounter(),
        buffer='',
        out=register_str,
        read=readmsg,
        send=sendmsg,
        close=closeconn})
end
--Loop
--Polls threads. If any bits set, run appropriate method
--If thread not closed, add to new threads queue
loop=function()
    while true do
        local stat, code = nixio.poll(threads,1000)
        if stat and stat>0 then
            local oldthreads=threads
            threads={}
            for i=1,#oldthreads do
                local thread=oldthreads[i]
                if bcheck(thread.revents,1)
                    and thread.read(thread)=='close'
                    or bcheck(thread.revents,4)
                    and thread.send(thread)=='close' then
                    thread.close(thread)
                else
                    table.insert(threads,thread)
                end
            end
        end
    end
end

--[[        local i,thread=1,threads[1]
        while thread do
            if thread.timestamp then
                if os.time() - thread.timestamp>=10 then
                    thread.close()
                    table.remove(threads,i)
                else break end
            else i=i+1 end
            thread=threads[i] 
        end]]
