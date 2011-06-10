local core=require'ox.core'
local http=require'ox.http'
local nixio=require'nixio','nixio.util'
local host='localhost'
local port=8888
local request = 'GET / HTTP/1.1\r\n\r\n'

local pid = nixio.fork()
if pid==0 then
  http.GET['^/$'] = function(c)
    http.reply(c, 200, "Hello")
  end
  http.GET['^/shutdown$'] = function(c)
    os.exit()
  end
  assert(http.serve(port))
  core.loop()
else


tests={}
tests['responds to request'] = function()
  print('send an HTTP request and read response')
  local pid=nixio.fork()
  if pid==0 then
    local mysock=nixio.connect(host,port)
    print('mysock: ',mysock)
    print('peername: ',mysock:getpeername())
    print('writing: ',mysock:write(request)
    print('reading: ',mysock:read(1024))
    print('closing: ',mysock:close())
  else
    http.GET['^/$'] = function(c)
      http.reply(c, 200, "Hello")
    end
    http.serve(port,http)
    core.loop()
  end
end

tests['nonblocking'] = function()
  print('open a second request before writing first to ensure nonblocking')
  local pid=nixio.fork()
  if pid==0 then
    local mysock=nixio.connect(host, port)
    local mysock2=nixio.connect(host, port)
    mysock2:write(request)
    mysock2:read(1024)
    mysock2:close()
    mysock:write(request)
    mysock:read(1024)
    mysock:close()
  end
end

tests['

tests['url_encode, url_decode'] = function()
  local str="hello x me = ss?q=23&23age Message /!@#& @("
  assert(str==http.url_decode(http.url_encode(str)))
end

tests['qs_decode'] = function()
  local t = http.qs_decode('message='..http.url_encode(str)..'&bool=')
  assert(t.message==str and t.bool==true)
end

tests['server, client, call_fork'] = function()
end

for k,v in pairs(tests) do
  print(k)
  fn()
end
print('\t','pass.')
