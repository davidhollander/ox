local ox = require 'ox'

assert(ox.bcheck(3,1)
  and ox.bcheck(3,2) 
  and not ox.bcheck(64,32)
)

local c = {events = 0}
ox.on_read(c, print)
assert(c.on_read == print)
assert(ox.bcheck(c.events,1))
ox.on_write(c, print)
assert(c.on_write == print)
assert(ox.bcheck(c.events,4))

assert(ox.bcheck(c.events, 1) and c.on_read)
ox.stop_read(c)
assert(not ox.bcheck(c.events, 1) and not c.on_read)


assert(ox.bcheck(c.events, 4) and c.on_write)
ox.stop_write(c)
assert(not ox.bcheck(c.events, 4) and not c.on_write)

local d = {events = 0}
ox.on_transfer(d, c, print)
assert(d.events==4 and d.on_write)
assert(c.events==1 and c.on_read)

local ffi = require 'ffi'
local pfds = ffi.new 'int[2]'
ffi.C.pipe(pfds)
ffi.C.write(pfds[1], 'hello', 5)

local z = {fd = pfds[0], events=0, revents=0}
ox.on_read(z, print)
ox.start()
