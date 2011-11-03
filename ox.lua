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
typedef long ssize_t;
typedef long off_t;
]]

-- structs
cdef[[
struct pollfd {int fd; short events; short revents;};
struct sockaddr {sa_family_t sa_family; char sa_data[14];};
struct in6_addr {unsigned char s6_addr[16];};
struct in_addr {uint32_t s_addr;};
struct sockaddr_in {
  sa_family_t sin_family;
  uint16_t sin_port;
  struct in_addr sin_addr;
  unsigned char  sin_zero[8];
};
struct sockaddr_in6 {
  uint16_t sin6_family;
  uint16_t sin6_port;
  uint32_t sin6_flowinfo;
  struct in6_addr sin6_addr;
  uint32_t sin6_scope_id;
};
struct sockaddr_un {
  sa_family_t sun_family;
  char sun_path[108];
}
struct addrinfo{
  int ai_flags;
  int ai_family;
  int ai_socktype;
  int ai_protocol;
  size_t ai_addrlen;
  struct sockaddr *ai_addr;
  char *ai_canonname;
  struct addrinfo *ai_next;
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
int write(int fd, const char * buffer, int n);
int socket(int domain, int type, int protocol);
int inet_pton(int af, const char *src, void *dst);
int bind(int sockfd, const struct sockaddr *myaddr, socklen_t addrlen);
int accept4(int sockfd, struct sockaddr *addr, socklen_t *addrlen, int flags);
int listen(int fd, int backlog);
int pipe(int filedes[2]);
int pipe2(int intfiledes[2], int flags);
int fcntl(int fd, int cmd, long arg);
int poll(struct pollfd *fds, nfds_t nfds, int timeout);
int connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
int getaddrinfo(const char *node, const char *service, const struct addrinfo *hints,
  struct addrinfo **res);
void freeaddrinfo(struct addrinfo *res);
const char * inet_ntop(int af, const void *src, char *dst, socklen_t cnt);
ssize_t sendfile(int out_fd, int in_fd, off_t *offset, size_t count);
int setsockopt(int s, int level, int optname, const void *optval, socklen_t optlen);
]]
-- constants
local F_SETFL = 4
local AF_UNIX, AF_INET, AF_INET6 = 1, 2, 10
local SOCK_STREAM, SO_REUSEADDR = 1, 2
local SOL_SOCKET = 1
local O_NONBLOCK, SOCK_NONBLOCK = 2048, 2048
local EV_IN, EV_OUT = 1, 4
local EINTER, EAGAIN, EINPROGRESS = 4, 11, 115
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
  TIME_WARP = 0,
  TIMEOUT = 20,
  TIMEOUT_INT=5,
  children = {},
}

function ox.pass() end

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

function ox.cron(t, fn)
  local t2 = os.date '*t'
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
  return ox.at(os.time(t2), fn)
end

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

-- AIO
--
local on_read, on_write, stop_read, stop_write = ox.on_read, ox.on_write, ox.stop_read, ox.stop_write
local vla_char = typeof 'char [?]'

function ox.close(c)
  C.close(c.fd)
  c.closed=true
end
local streambuff = ffi.new 'char[8192]'
function ox.readln(c, max, cb)
  if c.buffer then
    --print('readln c.buffer', max, #c.buffer, c.buffer)
    local h = c.buffer:find('\n', c.init, true)
    if h and h<max then
      local line = c.buffer:byte(h-1)==CR and c.buffer:sub(1, h-2) or c.buffer:sub(1, h-1)
      c.buffer = h==#c.buffer and nil or c.buffer:sub(h+1)
      c.init = 1
      return cb(c, line)
    elseif #c.buffer>max then return cb(c, nil)
    else c.init = #c.buffer end
  else c.buffer = '' end
  return ox.on_read(c, function(c)
    local n = C.read(c.fd, streambuff, 8192)
    if n==-1 then return errno()~=EAGAIN and ox.close(c) end
    c.buffer = c.buffer..ffi.string(streambuff, n)
    stop_read(c)
    return ox.readln(c, max, cb)
  end)
end

function ox.read(c, n, cb)
  return ox.on_read(c, function(c)
    local n = C.read(c, streambuff, n)
  end)
end

function ox.write(c, str, cb)
  local buff = ffi.cast('char *', str)
  local n, len = 0, #str
  return on_write(c, function()
    local i = C.write(c.fd, buff+n, len-n)
    if i==-1 then return errno()~=EAGAIN and ox.close(c)
    elseif n+i < len then n = n + m
    else stop_write(c); return cb(c) end
  end)
end

function ox.open(file, mode)
  local flags = mode == 'r' and C.O_RDONLY or mode=='w' and C.O_WRONLY or mode=='rw' and C.O_RDWR
  if not flags then return nil, 'Bad mode: r, w, rw' end
  local fd = C.open(file, mode)
  if fd==-1 then return nil, 'Could not open'
  else return {fd = fd} end
end
function ox.fsync(c)

end


function ox.sendfile(file, des, offset, len, cb)
  local n = 0
  return on_write(c, function()
    local i = C.sendfile(des.fd, file.fd, offset, len)
    if i==-1 then return errno()~=EAGAIN and ox.close(c)
    elseif n+i<len then n = n+i
    else return cb(c) end
  end)
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

function ox.unixserv(file, cn)
  local addr = ffi.new('struct sockaddr_un', {sun_family=AF_UNIX,sun_path=file})
  local s = C.socket(AF_UNIX, SOCK_STREAM+SOCK_NONBLOCK, 0)   
  if s==-1 then return nil, 'could not create socket' end

  local myaddr = cast('struct sockaddr *', addr)
  local i = C.bind(s, myaddr, sizeof(addr))
  if i==-1 then return nil, 'Could not bind: '..errno() end
  local i = C.listen(s, 1024) 
  if i==-1 then return nil, 'Could not listen: '..errno() end

  local c = {fd = s, events = EV_IN, revents = 0, on_read = tcp_accept, on_accept = cn}
  ti(contexts, c)
  return true
end

function ox.unixconn(file, cb)
  local addr = ffi.new('struct sockaddr_un', {sun_family=AF_UNIX,sun_path=file})
  local myaddr = cast('struct sockaddr *', addr)
  local fd = C.socket(AF_UNIX, SOCK_STREAM+SOCK_NONBLOCK, 0)   
  if fd==-1 then return nil, 'Could not create socket' end
  if C.connect(fd, myaddr, sizeof(addr))==-1 then return nil, 'Could not connect' end
  if C.fcntl(fd, F_SETFL, O_NONBLOCK)==-1 then return nil, 'Could not set nonblock' end
  local c = {fd = fd, events=0, revents = 0}
  ti(contexts, c)
  return cb(c)
end


function ox.tcpserv(port, cn)
  local ip6addr = new 'struct sockaddr_in6'
  ip6addr.sin6_family = AF_INET6
  ip6addr.sin6_port = netorder(port)
  ip6addr.sin6_scope_id = 0
  ffi.copy(ip6addr.sin6_addr, LOOPBACK, sizeof(LOOPBACK))

  local s = C.socket(AF_INET6, SOCK_STREAM+SOCK_NONBLOCK, 0)
  if s==-1 then return nil, 'could not create socket: '..errno() end

  local opt = ffi.new 'int[1]'
  opt[0]=1
  if C.setsockopt(s, SOL_SOCKET, SO_REUSEADDR, opt, sizeof(opt))==-1 then
    return nil, 'Could not setsockopt', errno() end

  local myaddr = cast('struct sockaddr *', ip6addr)
  local i = C.bind(s, myaddr, sizeof(ip6addr))
  if i==-1 then return nil, 'could not bind: '..errno() end
   
  local i = C.listen(s, 1024) 
  if i==-1 then return nil, 'Could not listen: '..errno() end

  local c = {fd = s, events = EV_IN, revents = 0, on_read = tcp_accept, on_accept = cn}
  ti(contexts, c)
  return true
end
-- blocking DNS lookup
-- returns list of readable ip addresses
function ox.b_resolv(file, host)
  local hints = new 'struct addrinfo'
  local results = new 'struct addrinfo * [1]'
  hints.ai_family = 0
  hints.ai_socktype = SOCK_STREAM
  hints.ai_protocol = 0
  if C.getaddrinfo(host, port, hints, results)~=0 then return nil, 'could not resolve' end
  local buffer = vla_char(64)
  local r = results[0][0]
  repeat
    local ipaddr
    if r.ai_family == AF_INET then
      local sa = ffi.cast('struct sockaddr_in *', r.ai_addr)
      ipaddr = sa.sin_addr
    elseif r.ai_family == AF_INET6 then
      local sa = ffi.cast('struct sockaddr_in6 *', r.ai_addr)
      ipaddr = sa.sin6_addr
    end
    if C.inet_ntop(r.ai_family, ipaddr, buffer, 64)~=nil then
      local str = ffi.string(buffer)
      file:write(str,'\r\n')
    end
    r = r.ai_next
  until r==nil
  file:close()
  C.freeaddrinfo(results[0])
  buffer=nil
end

local lib = require 'ox.lib'

-- asynchronous DNS lookup pooler and cache
local host_cache = lib.cache1(function(host, cb)
  local r = ox.fromfork(function(w) return ox.b_resolv(w, host) end, 30)
  return ox.readln(r, 66, function(c, ip) ox.close(r); return cb(ip) end)
end, 3600)

function ox.tcpconn(address, port, cb)
  -- convert ip6 or ip4 to address
  local version, addr, sockaddr, fd
  if address:match ':' then 
    addr = new 'struct in6_addr'
    version = AF_INET6
    if C.inet_pton(AF_INET6, address, addr)~=1 then return nil, 'Could not parse ip6' end
  elseif address:match '^[%d%.]+$' then
    addr = new 'struct in_addr'
    version = AF_INET
    if C.inet_pton(AF_INET, address, addr)~=1 then return nil, 'Could not parse ip4' end
  else
    return host_cache(address, function(ip) return ox.tcpconn(ip, port, cb) end)
  end
  
  -- fill socket address
  if version == AF_INET6 then
    sockaddr = new 'struct sockaddr_in6'
    sockaddr.sin6_family = AF_INET6
    sockaddr.sin6_port = netorder(port)
    sockaddr.sin6_flowinfo = 0
    sockaddr.sin6_scope_id = 0
    ffi.copy(sockaddr.sin6_addr, addr, sizeof(addr))
  else
    sockaddr = new 'struct sockaddr_in' 
    sockaddr.sin_family = AF_INET
    sockaddr.sin_port = netorder(port)
    ffi.copy(sockaddr.sin_addr, addr, sizeof(addr))
  end
  local casted = cast('struct sockaddr *', sockaddr)

  -- create socket and connect
  fd = C.socket(version, SOCK_STREAM, 0)
  if fd==-1 then return nil, 'Could not create socket' end
  if C.connect(fd, casted, sizeof(sockaddr))==-1 then print(version, errno())return nil, 'Could not connect' end
  if C.fcntl(fd, F_SETFL, O_NONBLOCK)==-1 then return nil, 'Could not set nonblock' end
  local c = {fd = fd, events=0, revents = 0}
  ti(contexts, c)
  return cb(c)
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

-- Read asynchronously from a pipe, perform blocking writes in fork
-- @param fn: function(pipe). Use pipe:write(string, ...) to send information
-- @param cb: function(context). Use ox.read or ox.readln
-- @param expire: optional timeout in seconds
function ox.fromfork(fn, expire)
  local pfds = ffi.new 'int[2]'
  if C.pipe(pfds)==-1 then return nil, 'Could not create pipe'..errno()
  elseif C.fcntl(pfds[0], F_SETFL, O_NONBLOCK)==-1 then
    return nil, 'Could not set read end nonblocking' end

  local pid = C.fork()
  if pid==-1 then return nil, 'Could not fork'
  elseif pid==0 then
    local w = {fd = tonumber(pfds[1]), write = b_write, close = ox.close}
    fn(w)
    os.exit()
  else
    local r = {fd = tonumber(pfds[0]), pid=pid, events = 0, revents = 0, expire = expire}
    ti(contexts, r)
    return r
  end
end

-- Write asynchronously to a pipe, perform blocking reads in fork
-- @param fn: function(pipe). Use pipe:read(number) to read information
-- @param cb: function(context). Use ox.write
-- @param expire: optional timeout in seconds
function ox.tofork(fn, expire)
  local pfds = ffi.new 'int[2]'
  if C.pipe(pfds)==-1 then return nil, 'Could not create pipe'..errno()
  elseif C.fcntl(pfds[1], F_SETFL, O_NONBLOCK)==-1 then
    return nil, 'Could not set write end nonblocking' end

  local pid = C.fork()
  if pid==-1 then return nil, 'Could not fork'
  elseif pid==0 then
    local r = {fd = tonumber(pfds[0]), read = b_read, close = ox.close}
    fn(r)
    os.exit()
  else
    local w = {fd = tonumber(pfds[1]), pid=pid, events = 0, revents = 0, expire = expire}
    ti(contexts, w)
    return w
  end
end




-- PIPE
--
function ox.pipe(flag, expire)
  local pfds = ffi.new 'int[2]'
  local r, w
  if flag =='rw' then
    if C.pipe2(pfds, O_NONBLOCK)==-1 then return nil, 'Could not create nonblocking pipe'..errno()
    else
      r = {fd = tonumber(pfds[0]), events = 0, revents = 0, expire=expire}
      w = {fd = tonumber(pfds[1]), events = 0, revents = 0, expire=expire}
      ti(contexts, r)
      ti(contexts, w)
    end
  elseif C.pipe(pfds)==-1 then return nil, 'Could not create pipe'..errno()
  elseif flag=='r' then
    if C.fcntl(pfds[0], F_SETFL, O_NONBLOCK)==-1 then
      return nil, 'Could not set only read end nonblocking'..errno()
    else
      r = {fd = tonumber(pfds[0]), events = 0, revents = 0, expire = expire}
      ti(contexts, r)
      w = {fd = tonumber(pfds[1]), write = b_write, close = ox.close}
    end
  elseif flag=='w' then
    if C.fcntl(pfds[1], F_SETFL, O_NONBLOCK)==-1 then
      return nil, 'Could not set only write end nonblocking'..errno()
    else
      w = {fd = tonumber(pfds[1]), events = 0, revents = 0, expire=expire}
      ti(contexts, w)
      r = {fd = tonumber(pfds[0]), read = b_read, close = ox.close}
    end
  end
  return r, w
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

function ox.expire()
  local lazy
  local cutoff = ox.time - ox.TIMEOUT
  local old = contexts
  contexts = {}
  for i,c in ipairs(old) do
    if lazy or not c.accept_time then ti(contexts, c)
    elseif c.accept_time < cutoff then ox.close(c)
    else lazy=true; ti(contexts, c) end -- we know recently accepted are on top
  end
  return ox.at(ox.time + ox.TIMEOUT_INT, ox.expire)
end

function ox.start(init)
  ox.on = true
  if init then init() end
  ox.at(ox.time + ox.TIMEOUT_INT, ox.expire)
  while ox.on do
    ox.time = os.time()
    tick()
    fds = pollfds(#contexts, contexts)
    if C.poll(fds, #contexts, 1000) > 0 then
      local old = contexts
      contexts = {}
      for i=0, #old -1 do
        local c = old[i+1]
        if bcheck(fds[i].revents, EV_IN) then c:on_read() end
        if not c.closed and bcheck(fds[i].revents, EV_OUT) then c:on_write() end
        if not c.closed then ti(contexts, c) end
      end
    end
  end
end

return ox
