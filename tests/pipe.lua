local ox = require 'ox'
local ffi = require'ffi'
local C = ffi.C

local r, w = assert(ox.pipe 'r')
assert(r.fd and r.events and r.revents)
assert(w.fd and w.write and w.close)
ox.close(r)
w:close()
ox.clear()

local r, w = assert(ox.pipe 'w')
assert(r.fd and r.read and r.close)
assert(w.fd and w.events and w.revents)
ox.close(w)
r:close()
ox.clear()

local r, w = assert(ox.pipe 'rw')
assert(r.fd and r.events and r.revents)
assert(w.fd and w.events and w.revents)
ox.close(r)
ox.close(w)

print 'pass'
