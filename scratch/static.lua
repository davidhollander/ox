local ox=require'ox'
local nixio=require'nixio'

RPC={GET={}}
RPC.GET['^/static/(.+)$']=function(client,path)
    local f=io.open(path,'r')
    if f then
        client.send=function(client)
            while true do
                local data=f:read(8192)
                if data then
                    local n=client.fd:send(data)
                    if n<#data then client.buffer=
                end
            end
        end
    end
end

--[[    if not FileStream(path,
        function(chunk)
            if chunk then table.insert(client.out,chunk)
            else client.close() end
        end)]]
 
FileRead=function(filethread)
--Get up to 1000 8192byte chunks until blocks
    for i=1,1000 do 
        local chunk=f:read(8192)
        if chunk then filethread.callback(chunk)
        elseif chunk==nil then filethread.callback()
        elseif chunk==false then break
        end
    end
end
FileStream=function(path,callback)
    local flags=nixio.open_flags('rdonly','nonblock')
    local f=nixio.open('static/'..capture,flags)
    if f then
        table.insert(threads,{
            fd=f,
            callback=callback,
            events=nixio.poll_flags('in'),
            revents=0,
            read=FileRead,
        })
    else return false end
end

ox.rpcserver(8081,RPC)
ox.loop()

