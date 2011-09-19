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

local _env = {}
function tbl.load(str)
  local f = loadstring('return '..str)
  return f and setfenv(f,_env)()
end

local mmax = math.max
local dumptype
dumptype = {
  table = function(out, t)
    ti(out, '{')
    for k,v in pairs(t) do
      local fk, fv = dumptype[type(k)], dumptype[type(v)]
      if fk and fv then
        ti(out, '['); fk(out, k); ti(out, ']='); fv(out, v)
      end
      ti(out, ',')
    end
    out[mmax(#out,2)]='}'
  end,
  string = function(out, k) return ti(out, ('%q'):format(k)) end,
  number = function(out, k) return ti(out, k) end,
}

function tbl.dump(i)
  local out = {}
  local fn = dumptype[type(i)]
  if fn then
    fn(out, i)
    return tc(out)
  else return nil, 'Unsupported type' end
end

return tbl
