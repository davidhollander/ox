local data=require 'ox.data'
local ti, tc= table.insert, table.concat

function makedata()
  local t={}
  for i=1,399,2 do ti(t, i) end
  for i=400,2,-2 do ti(t, i) end
  return t
end

local d=makedata()


function test()
  local b=data.obuffer(function(a,b) return a<b end, 10)
  for i,v in ipairs(d) do b(v) end
  local results, count =b()
  for i,v in ipairs(results) do assert(i==v) end
  assert(#results==10,'Should return 10 results: '..#results)
  assert(count==400, 'Should have checked 400 records: '..count)

  local b = data.obuffer(function(a,b) return a<b end, 10, 10)
  for i,v in pairs(d) do b(v) end
  local results, count = b()
  for i,v in pairs(results) do assert(i+10==v) end
  assert(#results==10,'Should have returned 10 results: '..#results)
  assert(count==400, 'Should have checked 400 records '..count)
end

test()
print('pass.')
