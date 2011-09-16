-- ox.tbl
-- Copyright (C) 2011 by David Hollander
-- MIT License, see LICENSE

local tbl = {}
local ti, tc = table.insert, table.concat

function tbl.count(t)
  local i = 0
  for _ in pairs(t) do i = i + 1 end
  return i
end

function tbl.keys(t)
  local out = {}
  for k in pairs(t) do
    ti(out, k)
  end
  return out
end

function tbl.values(t)
  local out = {}
  for _, v in pairs(t) do
    ti(out, v)
  end
  return out
end

return tbl
