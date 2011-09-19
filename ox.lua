-- ox
-- Copyright (C) 2011 by David Hollander
-- MIT License, see LICENSE


-- FFI
--
local ffi = require 'ffi'
local C = ffi.C
local cdef,cast,typeof,sizeof,errno,new = ffi.cdef,ffi.cast,ffi.typeof,ffi.sizeof,ffi.errno,ffi.new
-- typedefs
cdef[[
typedef int32_t pid_t;
typedef uint32_t mode_t;
typedef unsigned short int sa_family_t;
typedef uint32_t socklen_t;
typedef uint16_t in_port_t;
typedef unsigned long nfds_t;
]]
-- structs
cdef[[
struct pollfd {int fd; short events; short revents;};
struct sockaddr {sa_family_t sa_family; char sa_data[14];};
struct in6_addr {unsigned char s6_addr[16];};
struct sockaddr_in6 {
  uint16_t sin6_family;
  uint16_t sin6_port;
  uint32_t sin6_flowinfo;
  struct in6_addr sin6_addr;
  uint32_t sin6_scope_id;
};
]]
-- funcs
cdef[[
pid_t fork(void);
int kill(pid_t pid, int sig);
pid_t setsid(void);
int chdir(const char *path);
mode_t umask(mode_t mask);
int close(int fd);
int read(int fd, char * buffer, int n);
int write(int fd, char * buffer, int n);
int socket(int domain, int type, int protocol);
int inet_pton(int af, const char *src, void *dst);
int bind(int sockfd, const struct sockaddr *myaddr, socklen_t addrlen);
int accept4(int sockfd, struct sockaddr *addr, socklen_t *addrlen, int flags);
int listen(int fd, int backlog);
int pipe(int filedes[2]);
int pipe2(int intfiledes[2], int flags);
int fcntl(int fd, int cmd, long arg);
int poll(struct pollfd *fds, nfds_t nfds, int timeout);
]]
-- constants
local F_SETFL = 4
local SOCK_STREAM, AF_INET6, SO_REUSEADDR = 1, 10, 2
local O_NONBLOCK, SOCK_NONBLOCK = 2048, 2048
local EV_IN, EV_OUT = 1, 4
local EINTER, EAGAIN = 4, 11
local LOOPBACK = new 'struct in6_addr'
assert(C.inet_pton(AF_INET6, '::', LOOPBACK)>0, 'Could not cache ip6 loopback')


local CR = string.byte '\r'
local LF = string.byte '\n'
local mmin, mmax = math.min, math.max
local ti, tc = table.insert, table.concat
local bxor, band, bnot = bit.bxor, bit.band, bit.bnot
local maskin, maskout = bnot(EV_IN), bnot(EV_OUT)

-- MODULE
--
local ox = {
  on = false,
  log = print,
  time = os.time(),
  time_warp = 0,
  expire = 20,
  children = {},
}

function ox.logfile(name)
  local f = io.open(name, 'a+')
  function ox.log(...)
    f:write(...)
    f:flush()
  end
end

function ox.split(n, cb)
  local pids = {}
  for i=1, n do
    local pid = C.fork()
    if pid==0 then
      cb(i)
      os.exit()
    elseif pid==-1 then return nil, 'Could not fork'
    else pids[pid]=true end
  end
  for pid in pairs(pids) do ox.children[pid]=true end
end

function ox.kill(pid)
  if pid then
    return C.kill(pid, 9)
  end
  for pid in pairs(ox.children) do
    local i = C.kill(pid, 9)
    ox.log(pid, i)
    if i~=1 then ox.children[pid]=nil end
  end
end

function ox.daemon(c, cb)
  local pid = C.fork()
  if pid==-1 then return nil, 'Could not fork'
  elseif pid==0 then
    if c.log then ox.logfile(c.log) end
    --ox.log('daemon: ',tbl.dump(c),'\r\n')
    local i = C.setsid()
    if i==-1 then ox.log('daemon: Could not set session\r\n'); os.exit() end

    if c.path then
      local i = C.chdir(c.path)
      if i==-1 then ox.log('daemon: Could not set path\r\n'); os.exit() end
    end

    local i = C.umask(c.umask or 0)
    if i==-1 then ox.log('daemon: Could not set umask\r\n'); os.exit() end
    cb()
    ox.log(os.time(),'daemon: success\r\n')
    os.exit()
  else
    ox.children[pid] = true
  end
end

-- TIMERS
--
local timers = {}
function ox.at(utctime, cb)
  if utctime < ox.time then return nil, 'Must be in future'
  elseif timers[utctime] then ti(timers[utctime], cb)
  else timers[utctime]={cb} end
  return true
end; local at = ox.at

local function tick()
  if timers[ox.time] then
    for i,v in ipairs(timers[ox.time]) do v() end
    timers[ox.time]=nil
  end
end

-- POLL
--
local contexts = {}

function ox.bcheck(a, b)
  return band(a, b) == b
end

function ox.on_read(src, cb)
  src.on_read = cb
  src.events = bxor(src.events, EV_IN)
end

function ox.stop_read(src)
  src.on_read = nil
  src.events = band(src.events, maskin)
end

function ox.on_write(des, cb)
  des.on_write = cb
  des.events = bxor(des.events, EV_OUT)
end

function ox.stop_write(des)
  des.on_write = nil
  des.events = band(des.events, maskout)
end; local stop_write = ox.stop_write

function ox.on_transfer(des, src, cb)
  src.events = bxor(src.events, EV_IN)
  des.events = bxor(des.events, EV_OUT)
  src.on_transfer = cb
  des.on_transfer = cb
  local on_read, on_write  = false, false
  function src.on_read()
    if on_write then
      des.events = bxor(des.events, maskout)
      return cb(des, src)
    else
      on_read = true
      src.events = band(src.events, maskin)
    end
  end
  function des.on_write()
    if on_read then
      src.events = bxor(des.events, maskin)
      return cb(des, src)
    else
      on_write = true
      des.events = band(des.events, maskout)
    end
  end
end

-- AIO
--
local on_read, on_write, stop_read, stop_write = ox.on_read, ox.on_write, ox.stop_read, ox.stop_write
local vla_char = typeof 'char [?]'
local newbuffer = typeof 'char[8192]'

function ox.close(c)
  C.close(c.fd)
  c.closed=true
end

function ox.fill(src, cn)
  if not src.buff then src.buff = newbuffer() end
  return on_read(src, function()
    local i = C.read(src.fd, src.buff, 8192)
    if i==-1 then
      if errno() == EAGAIN then return
      else return ox.close(src) end
    else
      src.h = 0
      src.len = i
      return cn(src)
    end
  end)
end

local function _readln(src)
  local bufflimit = src.len - src.h
  local lnlimit = src.lnmax - src.k
  for i=0, mmin(lnlimit, bufflimit) do
    if src.buff[src.h + i] == LF then
      src.h = src.h + i + 1
      local j = src.k + i
      local n = (j > 0 and src.lnbuff[j - 1] == CR and j - 1) or j
      return src:on_line(ffi.string(src.lnbuff, n)) --?
    else
      src.lnbuff[src.k + i] = src.buff[src.h + i]
    end
  end
  if lnlimit<bufflimit then
    return src:on_line(nil, 'Exceeded max')
  else
    c.k = c.k + bufflimit
    return ox.fill(src, _readln)
  end
end

function ox.readln(src, max, cn)
  src.lnbuff = vla_char(max)
  src.on_line = cn
  src.lnmax = max
  src.k = 0
  if src.h then return _readln(src)
  else return ox.fill(src, _readln) end
end

function ox.read(src, n, cb)
end

function ox.write(des, str, cn)
  local buff = vla_char(#str, str)
  local n = 0
  return on_write(des, function()
    local m = C.write(des.fd, buff+n, #str - n)
    if m==-1 then return errno()~=EAGAIN and ox.close(des) end
    n = n + m
    if n>=#str then
      stop_write(des)
      return cn(des)
    end
  end)
end
function ox.transfer(des, src, n, cb)
end

-- TRANSPORT
--
local ptr_sockaddr = typeof 'const struct sockaddr *'
local struct_sockaddr_in6 = typeof 'struct sockaddr_in6'
local netorder
if ffi.abi 'be' then
  netorder = function(x) return x end --big endian
else
  netorder = function(x) return bit.rshift(bit.bswap(x), 16) end
end

local function tcp_accept(s)
  while true do
    local fd = C.accept4(s.fd, nil, nil, SOCK_NONBLOCK)
    if fd==-1 then return end
    local c = {fd = fd, events = 0, revents = 0, accept_time=ox.time}
    ti(contexts, c)
    s.on_accept(c)
  end
end

function ox.tcpserv(port, cn)
  local ip6addr = new 'struct sockaddr_in6'
  ip6addr.sin6_family = AF_INET6
  ip6addr.sin6_port = netorder(port)
  ffi.copy(ip6addr.sin6_addr, LOOPBACK, sizeof(LOOPBACK))

  local s = C.socket(AF_INET6, SOCK_STREAM+SOCK_NONBLOCK, 0)
  if s==-1 then return nil, 'could not create socket: '..errno() end
  local myaddr = cast('struct sockaddr *', ip6addr)
  local i = C.bind(s, myaddr, sizeof(ip6addr))
  if i==-1 then return nil, 'could not bind: '..errno() end
   
  local i = C.listen(s, 1024) 
  if i==-1 then return nil, 'Could not listen: '..errno() end

  local c = {fd = s, events = EV_IN, revents = 0, on_read = tcp_accept, on_accept = cn}

  ti(contexts, c)
  return true
end

function ox.tcpconn(host, port, cb)
end
function ox.unixserv(file, cb)
end
function ox.unixconn(file, cb)
end


-- BLOCKING IO
--
local function b_write(c, ...)
  local str = tc {...}
  local buff = vla_char(#str, str)
  local n = 0
  while n<#str do
    local m = C.write(c.fd, buff+n, #str - n)
    if m==-1 and ffi.errno()~=EINTER then break
    else n=n+m end
  end
end

local function b_read(c, N)
  local n = 0
  local buff = vla_char(N)
  while n<N do
    local m = C.read(c.fd, buff+n, #str -n)
    if m==-1 and ffi.errno()~=EINTER then break
    else n=n+m end
  end
  return ffi.string(buff, n)
end

-- PIPE
--
function ox.pipe(flag)
  local pfds = ffi.new 'int[2]'
  if flag =='rw' then
    if C.pipe2(pfds, O_NONBLOCK)==-1 then return nil, 'Could not create nonblocking pipe'..errno()
    else
      local r = {fd = tonumber(pfds[0]), events = 0, revents = 0}
      local w = {fd = tonumber(pfds[1]), events = 0, revents = 0}
      ti(contexts, r)
      ti(contexts, w)
      return r, w
    end
  elseif C.pipe(pfds)==-1 then return nil, 'Could not create pipe'..errno()
  elseif flag=='r' then
    if C.fcntl(pfds[0], F_SETFL, O_NONBLOCK)==-1 then
      return nil, 'Could not set only read end nonblocking'..errno()
    else
      local r = {fd = tonumber(pfds[0]), events = 0, revents = 0}
      ti(contexts, r)
      return r, {fd = tonumber(pfds[1]), write = b_write, close = ox.close}
    end
  elseif flag=='w' then
    if C.fcntl(pfds[1], F_SETFL, O_NONBLOCK)==-1 then
      return nil, 'Could not set only write end nonblocking'..errno()
    else
      local w = {fd = tonumber(pfds[1]), events = 0, revents = 0}
      ti(contexts, w)
      return {fd = tonumber(pfds[0]), read = b_read, close = ox.close}, w
    end
  end
end


-- LOOP
--
local pollfds = ffi.typeof 'struct pollfd[?]'
local bcheck = ox.bcheck

function ox.stop()
  print 'stop'
  ox.on = false
end

function ox.clear()
  for _, c in ipairs(contexts) do ox.close(c) end
  contexts = {}
  collectgarbage 'collect'
end

function ox.start(init)
  ox.on = true
  if init then init() end
  while ox.on do
    ox.time = os.time()
    tick()
    fds = pollfds(#contexts, contexts)
    if C.poll(fds, #contexts, 1000) > 0 then
      local old = contexts
      contexts = {}
      for i=0, #old -1 do
        local c = old[i+1]
        --print(c, fds[i].revents)
        if bcheck(fds[i].revents, EV_IN) then c:on_read() end
        if not c.closed and bcheck(fds[i].revents, EV_OUT) then c:on_write() end
        if not c.closed then ti(contexts, c) end
      end
    end
  end
end

return ox
