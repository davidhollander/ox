-- ox.data
-- Copyright (c) 2011 David Hollander
-- Released under the simplified BSD license, see LICENSE.txt

-- asynchronous caches and data structures

local ti, tc, ts =table.insert, table.concat, table.sort
module(... or 'ox.data',package.seeall)
-- pools requests for update(cb) and caches response for [timeout] duration
-- return lambda(cb)
function cache_single(update, timeout)
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
function cache_table(update, timeout)
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


