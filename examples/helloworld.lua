local core=require'ox.core'
local http=require'ox.http'

local site = http.host 'localhost'

site.GET['^/$'] = function(c)
  print 'handling'
  c:reply(200, "Hello World")
end

http.serve(8080, {localhost=site})
print(8080)
core.loop()
