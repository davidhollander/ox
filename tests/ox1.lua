local ox = require 'ox'
local tbl = require 'ox.tbl'
local lib = require 'ox.lib'

os.execute 'rm *.test'

print 'init'
assert(ox.log==print, 'init log')
assert(ox.time==os.time(), 'init time')
assert(ox.expire==20, 'init timeout 20')

ox.start(function()
  assert(ox.on, 'on')
  ox.stop()
end)
assert(not ox.on, 'off')

print 'split'
local NSPLIT = 3
ox.split(NSPLIT, function(id)
  local children = tbl.keys(ox.children)
  assert(#children==0,'split children should have 0 children: '..#children)
  assert(id>0 and id<=NSPLIT, 'bad id')
  local f = io.open('__split'..id..'__.test','w')
  f:write 'pass'
  f:flush()
  f:close()
end)
local children = tbl.keys(ox.children)
print('ox.split', table.concat(children,', '))
assert(#children == NSPLIT, '#children not'..NSPLIT..' : '..#children)
lib.sleep(1)
for i=1,NSPLIT do assert(io.open('__split'..i..'__.test')):close() end

print 'kill/clear closed'
ox.kill()
local children = tbl.keys(ox.children)
assert(#children== 0, 'kill did not remove all children: '..#children)
os.execute 'rm *.test'

print 'kill running'
ox.split(NSPLIT, function(id)
  lib.sleep(1)
  local f = io.open('__split'..id..'__.test','w')
  f:write 'fail'
  f:flush()
  f:close()
end)

ox.kill()
local count = 0
for i=1,NSPLIT do assert(not io.open('__split'..i..'__.test')) end

print 'pass'
