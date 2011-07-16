local core=require'ox.core'
local http=require'ox.http'

local p = http.parser()
local site = http.host()
s.localhost = site

site.GET['^/$'] = function(c)
  c:reply(200, "Hello World")
end

core.serve(8080, p)
print(8080)
core.loop()
