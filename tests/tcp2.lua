print 'this test requires apache bench!'

local ox = require 'ox'
local PORT = ... or 8091
local N = 10000
local test = 'ab -c 500 -n '..N..' http://localhost:'..PORT..'/'
local testline = 'GET / HTTP/1.0'

assert(ox.tcpserv(PORT, function(c)
  return ox.readln(c, 2048, function(c, line)
    assert(line==testline, 'ab or readln fail: '..line..' vs. '..testline)
    return ox.close(c)
  end)
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
