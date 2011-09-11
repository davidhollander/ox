local ffi = require 'ffi'
local L = require 'ox.lib'
--local S= require'ox.sys'

local charptr = ffi.typeof('char [?]')
local str = ('0123456789abcd\r\n'):rep(64)
local buff = charptr(1025, str)
local len = 1024

-- MOCKUP
--
ti, tc = table.insert, table.concat
text = "GET /stuff HTTP/1.1\r\nHeaderHeader: HeaderStuff\r\nHeaderHeaderHeader: HeaderHea der Header Header stuff\r\nBodyBodyBodyBodyBodyBodyBodyBodyBodyBodyBodyBodyBodyBodyBodyBodyBodyBodyBodyBodyBodyBodyBodyBody\r\n"
local chunks = {}
local n = 30
for i=1,#text,n do
  ti(chunks, (text:sub(i,i+n-1)))
end
assert(tc(chunks)==text)

local charchunks = {}
function setchunks(t)
  for i,v in ipairs(t) do
    local x = charptr(#v)
    ffi.copy(x, v)
    charchunks[i]={x, #v}
  end
end
--[[
for i,v in ipairs(chunks) do
  local x = charptr(#v)
  ffi.copy(x, v)
  charchunks[i]={x, #v}
end]]

function fill(c, cb)
  c._ = (c._ or 0) +1
  local x = charchunks[c._]
  if x then
    c.len = charchunks[c._][2]
    c.buff = charchunks[c._][1]
    return cb(c)
  end
end

-- API
--
local _readln_border, _readlnB

local function _readln_border(c)
  if c.buff[0]==10 then
    c.h=c.len>1 and 1 or nil
    local k=c.k
    c.k=nil
    return c.lncb(ffi.string(c.buff2, k))
  else
    c.buff2[c.k]=13
    c.k=c.k+1
    return _readlnB(c)
  end
end

-- possible read and write offset
local function _readlnB(c)
  local h = c.h or 0
  local k = c.k or 0
  local l = c.len - h
  local m = c.max - k
  local a = c.buff + h
  local b = c.buff2 + k
  c.k, c.h = nil, nil

  if m+2 < l then --max is limiting factor
    for i=0, m+1 do
      if a[i]==13 and a[i+1]==10 then
        c.h=h+i+2
        return c.lncb(ffi.string(c.buff2, i+k))
      else b[i]=a[i] end
    end
    return c.lncb(nil, 'Exceeded max')
  else --buffer is limiting factor
    for i=0, l-2 do
      if a[i]==13 and a[i+1]==10 then
        c.h = i<l-2 and h+i+2 or nil
        return c.lncb(ffi.string(c.buff2, i+k))
      else b[i]=a[i] end
    end

    --not found in buffer
    if a[l-1]==13 then
      c.k=k+l-1
      return fill(c, _readln_border)
    else
      b[l-1]=a[l-1]
      c.k=k+l
      return fill(c, _readlnB)
    end
  end
end

-- entry point
function readln(c, max, cb)
  c.k=nil
  c.max = max
  c.lncb = cb
  c.buff2 = charptr(max)
  if c.h then return _readlnB(c)
  else return fill(c, _readlnB) end
end


-- TEST
--

print 'test'
local i=0
setchunks {'abcdef\r\n'}
readln({}, 30, function(line) i=i+1 assert(line=='abcdef') end)

setchunks {'abcdef\r\nbar'}
readln({}, 30, function(line) i=i+1 assert(line=='abcdef') end)

setchunks {'abcdef','\r\nbar'}
readln({}, 30, function(line) i=i+1 assert(line=='abcdef') end)

setchunks {'abcdef\r','\nbar'}
readln({}, 30, function(line) i=i+1 assert(line=='abcdef') end)

setchunks {'abcdef\r\n','bar'}
readln({}, 30, function(line) i=i+1 assert(line=='abcdef') end)

setchunks {'abcdef','\r\n','bar'}
readln({}, 30, function(line) i=i+1 assert(line=='abcdef') end)

setchunks {'abcdef','\r','\n','bar'}
readln({}, 30, function(line) i=i+1 assert(line=='abcdef') end)

setchunks {'abcdef\r\n','bar\r\n'}
local c = {}
readln(c, 30, function(line) i=i+1 assert(line=='abcdef') end)
readln(c, 30, function(line) i=i+1 assert(line=='bar') end)


setchunks {'hello','\r\n','world','\r\n'}
local c = {}
readln(c, 30, function(line) i=i+1 assert(line=='hello') end)
readln(c, 30, function(line) i=i+1 assert(line=='world') end)

setchunks {'hello\r','\n','world\r','\n'}
local c = {}
readln(c, 30, function(line) i=i+1 assert(line=='hello') end)
readln(c, 30, function(line) i=i+1 assert(line=='world') end)

setchunks {'\r','\n'}
readln({}, 0, function(line) i=i+1 assert(line=='') end)

setchunks {'abcdefghijklmnopqrs\r\n'}
readln({}, 2, function(line, err) i=i+1 assert(not line and err) end)

assert(i==15)
print 'pass.'
