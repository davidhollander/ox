-- ox.data
-- Copyright (c) 2011 David Hollander
-- Released under the simplified BSD license, see LICENSE.txt

-- asynchronous caches and data structures

local ti, tc =table.insert, table.concat
module(... or 'ox.data',package.seeall)

-- pools asynchronous requests and caches response
-- update: function(key, cb) to be run when stale
-- ensures update is not run simultaneously for the same key
function cache(update)
  local data={}
  local status={}
  local waiting={}
  return function(key, cb)
    print('Getting '..key..' from cache')
    print(data[key], status[key], waiting[key] and #waiting[key])
    if status[key] then cb(data[key])
    else
      if status[key]==nil then
        status[key]=false
        update(key, function(val)
          print('update done, got '..val)
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
