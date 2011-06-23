local core = require 'ox.core'
local data = require 'ox.data'
local nixio = require'nixio'

local count=0
local timeout=2
local my_cache_single = data.cache0(function(cb)
  print 'computing update in fork...'
  count=count+1
  core.call_fork(function() nixio.nanosleep(1); return count end, cb)
end, timeout)

print 'fetch from cache 10 times'

local results={}
local j=0
for i=1,10 do
  my_cache_single(function(val)
    j=j+1
    results[i]=val
    if j==10 then return test2() end
  end)
end

function test2()
  print 'wait for cache to timeout and repeat'
  nixio.nanosleep(timeout+1)
  local k=0
  for i=11,20 do
    my_cache_single(function(val)
      k=k+1
      results[i]=val
      if k==10 then return assert_stuff() end
    end)
  end
end

function assert_stuff()
  print('asserting stuff')
  print(results[1],results[11])
  for i=2,10 do
    assert(results[i]==results[1],'first 10 fetches were inconsistent!')
  end
  for i=12,20 do
    assert(results[i]==results[11],'second 10 fetches were inconsistent!')
  end
  assert(count==2,'The cache was updated '..count..' times instead of 2!')
  print 'get without updating'
  my_cache_single(function(val)
    print(val)
    assert(count==2, 'The cache should still have only updated twice: '..count)
  end)
  print 'manually expire'
  my_cache_single()
  print 'get and update'
  my_cache_single(function(val)
    print(val)
    assert(count==3, 'The cache should have updated 3 times: '..count)
  end)
  core.stop()
end

core.loop()
print 'pass.'
