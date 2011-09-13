local ffi = require 'ffi'

collectgarbage 'stop'

local charptr = ffi.typeof 'char [?]'

local c = {}

function bar(c)
  c.bar = charptr(2048)
end

function foo(c)
  c.foo = charptr(2048)
  for i=1,100 do
    c.foo[i]=c.bar[i]
  end
end

for i=1,10000 do
  bar(c)
  foo(c)
  foo(c)
  bar(c)
  foo(c)
end


local t = {}

function on_read(c, cb)
  c.events = 4
  c.write = cb
end

function fill(c)
  if not c.buff then c.buff=charptr(2048) end
  on_read(c, function()
    local a = c.buff + 1
  end)
end

function read(c)
  c.buff2 = charptr(2048)
  return fill(c)
end

local c = {}
table.insert(t, c)
read(c)
read(c)
read(c)
read(c)
collectgarbage 'collect'
print 'ok'
