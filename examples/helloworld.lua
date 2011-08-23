local core=require'ox.core'
local http=require'ox.http'

http.hosts['^localhost'] = {GET={}}
local get = http.hosts['^localhost'].GET

get['^/$'] = function(c)
  c:reply(200, "Hello World")
end

print(http.serve(8080))
print(8080)
core.loop()
