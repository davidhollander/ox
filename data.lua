-- ox.data
-- Copyright (c) 2011 David Hollander
-- Released under the simplified BSD license, see LICENSE.txt

-- asynchronous caches and data structures

local ti, tc =table.insert, table.concat
module(... or 'ox.data',package.seeall)

-- pools asynchronous requests and caches response
-- update: function(key, cb) to be run when stale
--[[ ensures update is not run simultaneously for the same key
function cache(update)
  local data={}
  local status={}
  local waiting={}
  return function(key, cb)
    if status[key] then cb(data[key])
    else
      if status[key]==nil then
        status[key]=false
        update(key, function(val)
          data[key]=val
          status[key]=true
          for i,fn in ipairs(waiting[key]) do fn(val) end
          waiting[key]=nil
        end)
      end
      if waiting[key] then ti(waiting[key], cb)
      else waiting[key]={cb} end
    end
  end
end
]]

-- pools requests for update(cb)
function pool_single(update)
  local waiting=false
  return function(cb)
    if waiting then ti(waiting, cb)
    else
      waiting={cb}
      update(function(val)
        local waiting_old=waiting
        waiting=false
        for i,fn in ipairs(waiting_old) do fn(val) end
      end)
    end
  end
end
-- pools requests for update(key, cb)
function pool_table(update)
  local waiting={}
  return function(key, cb)
    if waiting[key] then ti(waiting[key], cb)
    else
      waiting[key]={cb}
      update(key, function(val)
        local waiting_old=waiting[key]
        waiting[key]=nil
        for i,fn in ipairs(waiting_old) do fn(val) end
      end)
    end
  end
end
-- pools requests for update(cb) and caches response for [timeout] duration
-- return lambda(cb)
function cache_single(update, timeout)
  local value
  local time=0
  local waiting=false
  return function(cb)
    print(waiting,time,value)
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

--[[
function quorum(t,R,N,fn)
end

--  form a quorum for t[n](key,cb) that callback with a value
function quorum_get(t,R,N)
  return function(val)
  end
end

-- form a quorum for t[n](key,val,cb) that callback with a boolean
function quorum_put(t,R,N)
  return function(val)
  end
end]]
