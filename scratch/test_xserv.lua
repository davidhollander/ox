local nixio=require'nixio',require'nixio.util'
require'myutils'
host='localhost'
port=8888
test1=function()
--sends an HTTP request and reads response
    local mysock=nixio.connect(host,port)
    print('mysock: ',mysock)
    print('peername: ',mysock:getpeername())
    print('writing: ',mysock:write('GET / HTTP/1.1\r\n\r\n'))
    print('reading: ',mysock:read(1024))
    print('closing: ',mysock:close())
end

test2=function()
--Try a second connection before writing first request
    local mysock=nixio.connect(host,port)
    print('mysock: ',mysock)
    print('peername: ',mysock:getpeername())
    test1()
    print('writing: ',mysock:write('GET / HTTP/1.1\r\n\r\n'))
    print('reading: ',mysock:read(1024))
    print('closing: ',mysock:close())
end

test3=function()
--Try sending request slowly
    local mysock=nixio.connect(host,port)
    print('mysock: ',mysock)
    print('peername: ',mysock:getpeername())
    print('writing: ',mysock:write('GET / '))
    nixio.nanosleep(1)
    print('writing: ',mysock:write('HTTP/'))
    nixio.nanosleep(1)
    print('writing: ',mysock:write('1.1\r\n\r\n'))
    print('reading: ',mysock:read(1024))
    print('closing: ',mysock:close())
end

test4=function()
--connect then hang up without sending
--make sure server does not infinite loop
    local mysock=nixio.connect(host,port)
    print('mysock: ',mysock)
    print('peername: ',mysock:getpeername())
    print('closing: ',mysock:close())
end
test5=function()
--wait over 10s before responding
--make sure server timesout connection
    local mysock=nixio.connect(host,port)
    print('mysock: ',mysock)
    print('peername: ',mysock:getpeername())
    nixio.nanosleep(12)
    print('writing: ',mysock:write('GET / HTTP/1.1\r\n\r\n'))
    print('reading: ',mysock:read(1024))
    print('closing: ',mysock:close())
end
test6=function()
--try to block a socket on write
    buffer=makebuffer()
    for i=1,(21200) do buffer('0123456789') end
    local mysock=nixio.connect(host,port)
    print('mysock: ',mysock)
    print('peername: ',mysock:getpeername())
    print('writing: ',mysock:write(buffer()))
    print('done writing1')
    print('writing: ',mysock:write(buffer()))
    print('done writing2')
    print('reading: ',mysock:read(1024))
    print('closing: ',mysock:close())
end
