-- ox.lib
-- Copyright 2011 by David Hollander
-- Distributed under the MIT License


local ffi = require 'ffi'
local cdef = ffi.cdef
local ti, tc = table.insert, table.concat
local lib = {}

-- FFI
--
-- 'sleep', 'compress', 'uncompress' by Mike Pall: http://luajit.org/ext_ffi_tutorial.html

cdef[[
void Sleep(int ms);
int poll(struct pollfd *fds, unsigned long nfds, int timeout);
unsigned long compressBound(unsigned long sourceLen);
int compress2(uint8_t *dest, unsigned long *destLen,
        const uint8_t *source, unsigned long sourceLen, int level);
int uncompress(uint8_t *dest, unsigned long *destLen,
         const uint8_t *source, unsigned long sourceLen);
]]
local zlib = ffi.load(ffi.os == "Windows" and "zlib1" or "z")
local arr_uint8 = ffi.typeof 'uint8_t[?]'
local ptr_ulong = ffi.typeof 'unsigned long[1]'

if ffi.os == "Windows" then
  function lib.sleep(s)
    ffi.C.Sleep(s*1000)
  end
else
  function lib.sleep(s)
    ffi.C.poll(nil, 0, s*1000)
  end
end

function lib.compress(txt)
  local n = zlib.compressBound(#txt)
  local buf = arr_uint8(n)
  local buflen = ptr_ulong(n)
  local res = zlib.compress2(buf, buflen, txt, #txt, 9)
  assert(res == 0)
  return ffi.string(buf, buflen[0])
end

function lib.uncompress(comp, n)
  local buf = ffi.new("uint8_t[?]", n)
  local buflen = ffi.new("unsigned long[1]", n)
  local res = zlib.uncompress(buf, buflen, comp, #comp)
  assert(res == 0)
  return ffi.string(buf, buflen[0])
end

-- Lua only
--

function lib.bench(n,fn,...)
  local c = os.clock()
  for i=1,n do
    fn(...)
  end
  return os.clock() -c
end


local MARK = ('*'):byte()

function lib.globtrie_put(R, ptrn, n)
  if ptrn=='*' then R.catch = n return end
  local t = R
  for i=1,#ptrn do
    local b=ptrn:byte(i)
    t[b] = t[b] or {}
    t = t[b]
  end
  t.exit = n
end

function lib.globtrie_get(R, str)
  local forks, captures = {}, {}
  local capture 
  local t = R
  local i = 1

  while i<=#str do
    local b = str:byte(i)

    if capture then
      if t[b] then
        t=t[b]
        ti(captures, str:sub(capture,i-1))
        capture = false
      end
      i = i + 1
    else

      local f = t[MARK]
      if t[b] then -- is there a byte path
        t=t[b]
        i = i + 1
        if f then -- did we skip a glob path
          ti(forks, {f,i})
        end
      elseif f then t=f; capture = i -- no byte path, follow glob path
      elseif #forks>0 then --no paths, can we backtrack?
        t, i = unpack(forks[#forks])
        capture = i
        forks[#forks] = nil
      elseif R.catch then return R.catch, str --can't backtrack, is there a catchall?
      else return false end --no luck
    end
  end

  -- all bytes visited
  -- end any suffix capturs
  if capture then ti(captures, str:sub(capture)) end
  -- did string end on an exit?
  if t.exit then return t.exit, unpack(captures)
  elseif R.catch then return R.catch, str end
end

-- pools requests for update(cb) and caches response for [timeout] duration
-- return lambda(cb)
function lib.cache0(update, timeout)
  local value
  local time=0
  local waiting=false
  return function(cb)
    if not cb then time=0
    elseif time>os.time() then return cb(value)
    elseif waiting then ti(waiting, cb)
    else
      waiting={cb}
      update(function(val)
        value=val
        time=os.time()+timeout
        local waiting_old=waiting
        waiting=false
        for i,fn in ipairs(waiting_old) do fn(val) end
      end)
    end
  end
end

-- pools requests for update(key, cb) and caches response for [timeout] duration
-- return lambda(key, cb)
function lib.cache1(update, timeout)
  local values={}
  local times={}
  local waiting={}
  return function(key, cb)
    if not cb then times[key]=nil; values[key]=nil
    elseif times[key] and times[key]>os.time() then cb(values[key])
    elseif waiting[key] then ti(waiting[key], cb)
    else
      waiting[key]={cb}
      update(key, function(val)
        values[key]=val
        times[key]=os.time()+timeout
        local waiting_old=waiting[key]
        waiting[key]=nil
        for i,fn in ipairs(waiting_old) do fn(val) end
      end)
    end
  end
end

return lib
