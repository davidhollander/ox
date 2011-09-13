local ox=require'ox'
local http=require'ox.http'
local PORT = ... or 8096

http.host.localhost = {GET = {}}
local site = http.host.localhost

site.GET['^/$'] = function(c)
  print 'lol'
  c:reply(200, 'Hello World')
end

ox.tcpserv(PORT, http.accept)
print(PORT)
ox.start()
