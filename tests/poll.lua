local ox = require 'ox'

print 'ox.bcheck'
assert(ox.bcheck(3,1)
  and ox.bcheck(3,2) 
  and not ox.bcheck(64,32)
)
print 'on_read'
local c = {events = 0}
ox.on_read(c, print)
assert(c.on_read == print)
assert(ox.bcheck(c.events,1))

print 'on_write'
ox.on_write(c, print)
assert(c.on_write == print)
assert(ox.bcheck(c.events,4))

print 'stop_read'
assert(ox.bcheck(c.events, 1) and c.on_read)
ox.stop_read(c)
assert(not ox.bcheck(c.events, 1) and not c.on_read)

print 'stop_write'
assert(ox.bcheck(c.events, 4) and c.on_write)
ox.stop_write(c)
assert(not ox.bcheck(c.events, 4) and not c.on_write)

print 'on_transfer'
local d = {events = 0}
ox.on_transfer(d, c, print)
assert(d.events==4 and d.on_write)
assert(c.events==1 and c.on_read)

print 'inactive read pipes, ox.start'
for i=1,500 do
  local r, w = assert(ox.pipe 'r')
  w:close()
  ox.on_read(r, function() assert(false, 'should not have triggered on_read') end)
end
ox.at(ox.time + 1, ox.stop)
ox.start()
ox.clear()

print 'active read pipes, ox.start'
local n = 0
local function count()
  n=n+1
  if n==500 then ox.stop() end
end
for i=1,500 do
  local r, w = assert(ox.pipe 'r')
  w:write 'hello'
  ox.on_read(r, count)
end
ox.at(ox.time + 2, function()
  assert(false, 'should have already counted to 500 and stopped')
end)
ox.start()

print 'pass'
