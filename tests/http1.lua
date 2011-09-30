print 'this test requires apache bench!'

local ox = require 'ox'
local http = require'ox.http'
local PORT = ... or 8093
local N = 10000
local test = 'ab -c 1000 -n '..N..' http://localhost:'..PORT..'/'
local testline = 'GET / HTTP/1.0'

local tc = table.concat
http.route '*' '*' '*' (function(c, host, method, path)
  local body = ('Host: %s\nMethod: %s\nPath: %s\n'):format(host, method, path)
  return http.reply(c, 200, body)
end)

assert(ox.tcpserv(PORT, http.accept))

local p
ox.at(ox.time + 3, function()
  local results = p:read(480)
  local n = results:match 'Complete requests:%s+(%d+)'
  assert(n, 'Could not parse complete requests from apache bench')
  assert(tonumber(n) == N, 'Complete requests not equal to N')
  p:close()
  ox.stop()
end)

ox.start(function()
  p = assert(io.popen(test), 'Could not open apache bench')
end)

print 'pass'
