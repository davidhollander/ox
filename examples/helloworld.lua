local core=require'ox.core'
local http=require'ox.http'

http.GET['^/$'] = function(c)
  c:reply(200, "Hello World")
end
http.serve(8080)
print(8080)
core.loop()
