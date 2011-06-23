local core = require 'ox.core'
local data = require 'ox.data'
local nixio = require'nixio'
local tc=table.concat
local count={}
local timeout=2
local my_cache_table = data.cache1(function(key, cb)
  print 'computing update in fork...'
  count[key]=count[key] and count[key]+1 or 1
  core.call_fork(function() nixio.nanosleep(1); return key..','..count[key] end, cb)
end, timeout)


function test1()
  print 'fetch keys {1,2,3} from cache 10 times each'
  local j=0
  for k=1,3 do
    for i=1,10 do
      my_cache_table(k, function(val)
        j=j+1
        assert(val==k..',1', 'Key "'..k..'" should be at update 1: '..val)
        if j==30 then return test2() end
      end)
    end
  end
end

function test2()
  print 'wait for cache to timeout and repeat'
  nixio.nanosleep(timeout+1)
  local j=0
  for k=1,3 do
    for i=1,10 do
      my_cache_table(k, function(val)
        j=j+1
        assert(val==k..',2', 'Key "'..k..'" should be at update 2: '..val)
        if j==30 then return test3() end
      end)
    end
  end
end

function test3()
  print 'immediately get keys {2,3}'
  local j=0
  for k=2,3 do
    my_cache_table(k, function(val)
      j=j+1
      assert(val==k..',2', 'Key "'..k..'" should stil be at update 2: '..val)
      if j==2 then return test4() end
    end)
  end
end

function test4()
  print 'manually expire key 1'
  my_cache_table(1)
  print 'get and update key1'
  my_cache_table(1, function(val)
    assert(val=='1,3','Key 1 should be at update 3: '..val)
    return done()
  end)
end

function done()
  core.stop()
  print 'pass.'
end

test1()
core.loop()
