local tbl = require 'ox.tbl'

local t = {foo=3, bar=5}
assert(tbl.count(t) == 2)
local l = tbl.keys(t)
assert(#l == 2)
for i,v in ipairs(l) do assert(t[v]) end
local l2 = tbl.values(t)
assert(l2[1]+l2[2] == 8)

local t = {'helloworld',foo='bar',baz=5,[{foo='bar'}]={bar='baz'}}
local t2 = tbl.load(tbl.dump(t))

local n = 0
for k,v in pairs(t) do
  n=n+1
  if type(k)~='table' then
    assert(t2[k]==v)
  else
    assert(k.foo=='bar')
    assert(v.bar=='baz')
  end
end
assert(n==4)

assert(#{tbl.unpackn({},{},{})} == 0)
assert(#{tbl.unpackn({1,2},{3},{4,5,6,7})} == 7)

print 'pass'
