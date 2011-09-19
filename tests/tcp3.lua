print 'this test requires apache bench!'

local ox = require 'ox'
local PORT = ... or 8092
local N = 10000
local test = 'ab -c 500 -n '..N..' http://localhost:'..PORT..'/'
local testline = 'GET / HTTP/1.0'

local tc = table.concat
local function handle(c, line)
  assert(line==testline)
  return ox.write(c, tc {'HTTP/1.1 200 OK\r\n\r\n', line, '\r\n'}, ox.close)
end

assert(ox.tcpserv(PORT, function(c)
  return ox.readln(c, 2048, handle)
end))

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
