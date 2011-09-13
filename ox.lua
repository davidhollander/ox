-- ox
-- Copyright David Hollander 2011
-- github.com/davidhollander
-- Distributed under the MIT License

-- Contains the core event loop, timers, and transport listeners and connections

-- SHORTCUTS
--
local ffi = require'ffi'
local S = require 'ox.sys'
local L = require 'ox.lib'
local bit = require 'bit'
local ti, tc = table.insert, table.concat
local typeof, cast, sizeof, errno = ffi.typeof, ffi.cast, ffi.sizeof, ffi.errno
local mmin, mmax = math.min, math.max
local charptr = ffi.typeof 'char [?]'
local EV_OUT, EV_IN = S.POLLOUT, S.POLLIN

module(... or 'ox', package.seeall)
on = false
time = os.time()
timeout = 20
local contexts = {}

function on_read(c, cb)
  c.events = bit.bxor(c.events, S.POLLIN)
  c.read = cb
end
function on_write(c, cb)
  c.events = bit.bxor(c.events, S.POLLOUT)
  c.write = cb
end
function stop_read(c, cb)
  c.events = bit.band(c.events, bit.bnot(S.POLLIN))
  c.read = nil
end
function stop_write(c, cb)
  c.events = bit.band(c.events, bit.bnot(S.POLLOUT))
  c.write = nil
end
function bcheck(field, flag)
  return bit.band(field, flag)==flag
end
-- TCP
--

local _sa = cast(typeof 'struct sockaddr *', S.sockaddr_storage_t())
local _len = S.int1_t(sizeof(S.sockaddr_storage_t()))
local function tcp_accept(s)
  while true do
    local fd = S.accept4(s.fd, _sa, _len, S.O_NONBLOCK)
    if fd==-1 then break end
    local c = {fd = fd, events = 0, revents = 0}
    ti(contexts, c)
    s.on_accept(c)
  end
end


function open(name, flag)
  --local fl = S.O_NONBLOCK
  local fl = 0
  if flag=='r' then fl = fl+S.O_RDONLY
  elseif flag=='w' then fl = fl+S.O_WRONLY end
  local fd = S.open(name, fl)
  if fd==-1 then return nil, 'Could not open file' end

  local c = {fd = fd,events=0,revents=0}
  ti(contexts, c)
  print('opened',fd)
  return c
end

--- Create a tcp listener on port. Calls back with a table for each accepted connection.
-- @param port number
-- @param cb function
local one = ffi.new('int[1]')
function tcpserv(port, cb)
  local s = S.socket(S.AF_INET, S.SOCK_STREAM + S.O_NONBLOCK, 0)
  if s==-1 then return nil, 'Bad socket', errno() end

  if S.setsockopt(s, S.SOL_SOCKET, S.SO_REUSEADDR, one, sizeof(one))==-1 then
    return nil, 'Could not setsockopt', errno() end

  local addr = S.in_addr_t()
  if S.inet_aton('127.0.0.1', addr)==0 then return nil, 'Bad address', errno() end

  local sa = S.sockaddr_in_t(S.AF_INET, L.htons(port), addr)
  if not sa then return nil, 'Bad port', errno() end

  if S.bind(s, cast(typeof 'struct sockaddr *', sa), sizeof(sa))==-1 then
    return nil, 'Bad bind', ffi.errno() end
  if S.listen(s, 1024)==-1 then return nil, 'Bad listen', errno() end

  ti(contexts, {
    fd = s,
    events = S.POLLIN,
    revents = 0,
    read = tcp_accept,
    on_accept = cb
  })
  return true
end


-- AIO
--

--- Callback once when c.buff and c.len have new data
-- the idea is to always try reading a large amount (8192) to minimize system calls
function fill(c, cb)
  print('fill', c, cb)
  if c.buff==nil then c.buff = charptr(8192) end
  return on_read(c, function(c)
    print('on_read','fill',c)
    local m = S.read(c.fd, c.buff, 8192)
    if m==-1 then
      if ffi.errno()==S.EAGAIN then print 'EAGAIN' return
      else c.closed=true; return S.close(c.fd) end
    else c.len=tonumber(m); stop_read(c)  return cb(c) end
  end)
end

local _readln_border, _readlnB

local function _readln_border(c)
  print('readln_border',c,'c.len:',c.len,'c.h:',c.h,'c.k:',c.k)
  if c.buff[0]==10 then
    c.h=c.len>1 and 1 or nil
    local k=c.k
    c.k=nil
    return c.lncb(c, ffi.string(c.buff2, k))
  else
    c.buff2[c.k]=13
    c.k=c.k+1
    return _readlnB(c)
  end
end

-- possible read and write offset
local function _readlnB(c)
  print('_readlnB',c)
  local h = c.h or 0
  local k = c.k or 0
  local l = c.len - h
  local m = c.max - k
  local a = c.buff + h
  local b = c.buff2 + k
  c.k, c.h = nil, nil

  --print('readlnB','h: ',h,'k: ',k,'l: ',l,'m: ',m,'a: ',a,'b: ',b)

  if m+2 < l then --max is limiting factor
    for i=0, m+1 do
      if a[i]==13 and a[i+1]==10 then
        c.h=h+i+2
        return c.lncb(c, ffi.string(c.buff2, i+k))
      else b[i]=a[i] end
    end
    return c.lncb(c, nil, 'Exceeded max')
  else --buffer is limiting factor
    print 'buffer is limiting factor' 
    for i=0, l-2 do
      if a[i]==13 and a[i+1]==10 then
        c.h = i<l-2 and h+i+2 or nil
        print('c.h',c.h, 'i+k',i+k)
        return c.lncb(c, ffi.string(c.buff2, i+k))
      else print(l-2,i,string.char(c.buff[i+h])) b[i]=a[i]  end
    end

    --not found in buffer
    print 'not found in buffer'
    if a[l-1]==13 then
      c.k=k+l-1
      return fill(c, _readln_border)
    else
      b[l-1]=a[l-1]
      c.k=k+l
      return fill(c, _readlnB)
    end
  end
end

--- read the next \r\n delimited chunk at most length max
-- callback with string or nil if max exceeded
function readln(c, max, cb)
  print('readln',c,max)
  c.k=nil
  c.max = max
  c.lncb = cb
  c.buff2 = charptr(max)
  print('readln',c.h, c.buff2)
  if c.h then return _readlnB(c)
  else return fill(c, _readlnB) end
end

--- read exactly the next n bytes, callback with string
-- accounts for possible leftovers from readln
function read(c, n, cb)
  local buff, h

  if c.h then
    h = c.h
    local l = c.len - c.h
    if l<n then --n limiting factor
      c.h=c.h+n
      return cb(ffi.string(c.buff+h, n))
    else --buffer limiting factor
      buff = charptr(n, c.buff+h)
    end
  else
    h = 0
    buff = charptr(n) 
  end

  return on_read(c, function(c)
    local m = S.read(c.fd, buff+h, n-h)
    if m==-1 then
      if ffi.errno()==S.EAGAIN then return
      else c.closed=true; return S.close(c.fd) end
    else
      h = h + m
      if h>=n then
        stop_read(c)
        return cb(ffi.string(buff, h))
      end
    end
  end)
end

function write(c, str, cb)
  print('write', c, str, cb)
  local h = 0
  local n = #str
  local buff = charptr(n, str)
  print('Writebuff',buff)
  on_write(c, function()
    print('write','on_write',c)
    local m = S.write(c.fd, buff+h, n-h)
    if m==-1 then
      if ffi.errno()==S.EAGAIN then return
      else c.closed=true; return S.close(c.fd) end
    else
      h = h + m
      if h>=n then
        stop_write(c)
        return cb(c)
      end
    end
  end)
end
function close(c)
  print('close',c)
  c.closed=true
  return S.close(c.fd)
end


--- Transfer the next n bytes to destination connection table from a source table
-- Accounts for leftovers from readln operations performed on src, uses sendfile when possible
function transfer(des, src, n, cb)
  local buff, h

  if c.h then
    h = c.h
    local l = c.len - c.h
    if l<n then --n limiting factor
      c.h=c.h+n
      return write(des, c.buff+h, n, cb)
    else --buffer limiting factor
      buff = charptr(n, c.buff+h)
    end
  else
    h = 0
    buff = charptr(n) 
  end

  local rdy = false
  local function combine(c)
    if rdy then
      local m = S.sendfile(a.fd, b.fd, off, count)
      if m==-1 then
        if ffi.errno()==S.EAGAIN then
          src.events = S.POLLIN; des.events = S.POLLOUT; return
        else des.closed=true; src.closed=true return cb(nil, 'Error') end
      else end
    else rdy=true;  end
  end
  on_read(src, combine)
  on_write(des, combine)
end


-- TIMERS
--
local timers = {}

---Calls back once at time specified
function at(utctime, cb)
  print('at',utctime,cb)
  if utctime<time then return nil, 'Must be in future'
  elseif timers[utctime] then ti(timers[utctime], cb)
  else timers[utctime]={cb} end
  return true
end
---Calls back once in [sec] seconds from now.
function timeout(sec, cb) return at(time+sec, cb) end

---Calls back multiple times according to table t
function cron(t, fn)
  local t2 = os.date('*t')
  if not t.year then
    if not t.month then
      if not t.day then
        if not t.hour then
          if not t.min then
            if not t.sec then return nil, 'Table must specify sec, min, hour, day, month, or year'
            elseif t.sec<t2.sec then t2.min=t2.min+1 end
          elseif t.min<t2.min then t2.hour=t2.hour+1 end
        elseif t.hour<t2.hour then t2.day=t2.day+1 end
      elseif t.day<t2.day then t2.month=t2.month+1 end
    elseif t.month<t2.month then t2.year=t2.year+1 end
  end
  for k,v in pairs(t) do t2[k]=v end
  return at(os.time(t2), fn)
end

-- tick
local function tick()
  if timers[time] then
    for i,v in ipairs(timers[time]) do v() end
    timers[time]=nil
  end
end

-- SIGNALS
--
local signals={} 
function bind(name, fn) 
  if signals[name] then ti(signals[name], fn) 
  else signals[name]={fn} end 
end 
function trigger(name) for i,fn in ipairs(signals) do fn() end end 

-- LOOP
--
local function expire(timeout, timeout_int)
  local oldtime = time - timeout
  local old = contexts
  contexts = {}
  local brk = false
  for i,c in ipairs(old) do
    if brk then contexts[i] = c
    elseif not c.accept_time then ti(contexts, c)
    elseif c.accept_time < old then c.closed=true; S.close(c.fd) print 'expired'
    else brk=true; ti(contexts, c) end
  end
  at(time+timeout_int, function() expire(timeout, timeout_int) end)
end

function stop() on=false end

function start(timeout, timeout_int)
  --collectgarbage 'stop'
  expire(timeout or 20, timeout_int or 4)
  on = true
  while on do
    --print 'collectgarbage...'
    --collectgarbage 'collect'
    --print 'collected.'
    local fds = S.pollfds_t(#contexts, contexts)
    local stat = S.poll(fds, #contexts, 500)
    time = os.time()
    --print('poll:', contexts, #contexts, fds, n)
    if stat>0 then
      local old = contexts
      contexts = {}
      for i=0, #old-1 do
        local ev, c = fds[i], old[i+1]
        if bcheck(ev.revents, EV_OUT) then c:write() end
        if not c.closed and bcheck(ev.revents, EV_IN) then c:read() end
        if not c.closed then ti(contexts, c) end
      end
    end
    tick()
  end
end

return O
