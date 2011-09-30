local ox = require 'ox'
local http = require 'ox.http'
local PORT = ... or 8092
http.route '*' '*' '*' (function(c, host, method, path)
  --print(host, method, path)
  local body = ('Host: %s\nMethod: %s\nPath: %s\n'):format(host, method, path)
  return http.reply(c, 200, body)
end)

print(ox.tcpserv(PORT, http.accept))
print(PORT)
ox.start()
