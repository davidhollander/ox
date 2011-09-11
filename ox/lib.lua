--OXLIB
--
--David Hollander 2011 MIT License
--
--Library of pure Lua helpers for ox server library
--For new data structure operations, the Lua "table" standard library is emulated.
--Similar to "insert", operations take a table as the first argument, rather then
--encapsulating a new object with an :insert() method.

local S=require'ox.sys'
local L={}
local ti, tc = table.insert, table.concat
-- UTIL
--
function L.clock(n, fn, ...)
  local c = os.clock()
  for i=1,n or 1 do
    fn(...)
  end
  return os.clock() - c
end
function L.show(t)
  print(t)
  local a = {}
  for k, v in pairs(t) do ti(a, k) end
  table.sort(a)
  print(tc(a, ', '))
end


-- BIT
--
local bit = require 'bit'
function L.htons(b) return bit.rshift(bit.bswap(b), 16) end
function L.bcheck(revents, flag)
  return bit.band(revents, flag) == flag
end

-- STRUCTURES
--[[
function L.queue(Q)
  Q=Q or {}
  Q.i=1;Q.j=1
  return Q
end
function L.queue_put(Q, v)
  Q[Q.k] = v
  Q.n = Q.n and Q.n+1 or 1
end
function L.queue_pop(Q)
  local x = Q[Q.h]
  Q[Q.h]=nil
  Q.h=Q.h+1
  return x
end
function L.sortbuff(B, limit)
end
function L.sortbuff_put(B)
end
function L.sortbuff_get(B)
end]]

function L.cache0(update, timeout)
  local value
  local time=0
  local waiting=false
  return function(cb)
    if not cb then time=0
    elseif time>os.time() then return cb(value)
    elseif waiting then ti(waiting, cb)
    else
      waiting={cb}
      update(function(val)
        value=val
        time=os.time()+timeout
        local waiting_old=waiting
        waiting=false
        for i,fn in ipairs(waiting_old) do fn(val) end
      end)
    end
  end
end

-- pools requests for update(key, cb) and caches response for [timeout] duration
-- return lambda(key, cb)
function L.cache1(update, timeout)
  local values={}
  local times={}
  local waiting={}
  return function(key, cb)
    if not cb then times[key]=nil; values[key]=nil
    elseif times[key] and times[key]>os.time() then cb(values[key])
    elseif waiting[key] then ti(waiting[key], cb)
    else
      waiting[key]={cb}
      update(key, function(val)
        values[key]=val
        times[key]=os.time()+timeout
        local waiting_old=waiting[key]
        waiting[key]=nil
        for i,fn in ipairs(waiting_old) do fn(val) end
      end)
    end
  end
end

local t_serialize = {
  ['function'] = function(v) return string.dump(v) end,
  table = function(v)
    local t={}
    for k, v in pairs(v) do
      ti(t, tc {"[",L.serialize(k),"]=",L.serialize(v)})
    end
    return tc {'{',tc(t,','),'}'}
  end,
  string = function(v)
    return string.format('%q',v)
  end,
  boolean = function(v)
    return v and 'true' or 'false'
  end
}

function L.serialize(v)
  local f = t_serialize[type(v)]
  return f and f(v) or v
end


---create a buffer for pushing unorded items into ordered lists
--@ param sort   sorting function used by table.sort
--@ param limit  number of items to return
--@ ret lambda   lambda(): return ordered list, count. lambda(item): add item.
function L.obuffer(sort, n, skip)
  local stop=n+1+(skip or 0)
  local m=2*n+(skip or 0)
  local count=0
  local out={}
  local function trim()
    ts(out, sort)
    for i=#out,stop,-1 do out[i]=nil end
  end
  return function(item)
    if not item then trim()
      if not skip then return out, count
      else
        local t={}
        for i=1,n do t[i]=out[skip+i] end
        return t, count
      end
    else
      count=count+1
      ti(out, item)
      if #out>m then trim() end
    end
  end
end
return L
