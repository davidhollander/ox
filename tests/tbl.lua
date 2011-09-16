local tbl = require 'ox.tbl'

local t = {foo=3, bar=5}
assert(tbl.count(t) == 2)
local l = tbl.keys(t)
assert(#l == 2)
for i,v in ipairs(l) do assert(t[v]) end
local l2 = tbl.values(t)
assert(l2[1]+l2[2] == 8)

print 'pass'
