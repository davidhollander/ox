local core = require 'ox.core'
local http = require 'ox.http'
local data = require 'ox.data'
local nixio = require 'nixio'

-- This test shows how 10 requests can be pooled to make only a single blocking call

local port=8888
local count=0
function blocking()
  print('doblocking...')
  count=count+1
  assert(count==1,'Function blocking called more than once!'..count)
  nixio.nanosleep(1)
  return math.random(1000)
end

local mycache = data.cache(function(key, cb)
  print('doupdate...')
  core.call_fork(blocking, cb)
end)

http.GET['^/$'] = function(c)
  mycache('hello', function(val)
    http.reply(c, 200, val)
  end)
end


local body=false
local complete=0
for i=1,10 do
  http.fetch {
    host = 'localhost',
    port = port,
    success = function(res)
      complete=complete+1
      if body then assert(res.body==body, 'Differing response bodies')
      else body=res.body end
      if complete==10 then core.stop() end
    end
  }
end


assert(http.serve(port, http))
core.loop(10)
print('pass.')
