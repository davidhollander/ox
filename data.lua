-- ox.data
-- Copyright (c) 2011 David Hollander
-- Released under the simplified BSD license, see LICENSE.txt

-- asynchronous caches and data structures

local ti, tc, ts =table.insert, table.concat, table.sort

module(... or 'ox.data',package.seeall)
-- pools requests for update(cb) and caches response for [timeout] duration
-- return lambda(cb)
function cache0(update, timeout)
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
function cache1(update, timeout)
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

serialize=true
local t_serialize = {
  ['function'] = function(v) return string.dump(v) end,
  table = function(v)
    local t={}
    for k, v in pairs(v) do
      ti(t, tc {"[",serialize(k),"]=",serialize(v)})
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
serialize = function(v)
  local f = t_serialize[type(v)]
  return f and f(v) or v
end

---create a buffer for pushing unorded items into ordered lists
--@ param sort   sorting function used by table.sort
--@ param limit  number of items to return
--@ ret lambda   lambda(): return ordered list, count. lambda(item): add item.
function obuffer(sort, n, skip)
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
