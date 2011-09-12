local ox=require'ox'
local http=require'ox.http'
local PORT = 8092

http.host.localhost = {GET = {}}
local site = http.host.localhost

host.GET['^/$'] = function(c)
  c:reply(200, 'Hello World')
end

ox.tcpserv(PORT, http.accept)
print(PORT)
ox.start()
