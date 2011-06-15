local core=require'ox.core'
local http=require'ox.http'

http.GET['^/$'] = function(c)
  http.reply(c, 200, "Hello World")
end
http.serve(8080,http)
print(8080)
core.loop()
