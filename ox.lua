-- ox
-- Copyright (C) 2011 by David Hollander
-- MIT License, see LICENSE

-- REQUIRE
--
local ffi = require 'ffi'
local C = ffi.C
local cdef = ffi.cdef
local ti, tc = table.insert, table.concat

-- MODULE
--
local ox = {
  on = false,
  log = print,
  time = os.time(),
  expire = 20,
  contexts = {},
  children = {},
  C = C
}
function ox.logfile(name)
  local f = io.open(name, 'a+')
  function ox.log(...)
    f:write(...)
    f:flush()
  end
end

cdef 'typedef int32_t pid_t;'
cdef 'pid_t fork(void)'
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

cdef 'int kill(pid_t pid, int sig)'
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

cdef 'pid_t setsid(void)'
cdef 'int chdir(const char *path)'
cdef 'typedef uint32_t mode_t'
cdef 'mode_t umask(mode_t mask)'
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

-- POLL
--
local contexts = ox.contexts
local bxor, band, bnot = bit.bxor, bit.band, bit.bnot
local EV_IN, EV_OUT = 1, 4
local maskin, maskout = bnot(EV_IN), bnot(EV_OUT)
function ox.bcheck(a, b)
  return band(a,b) == b
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
end
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

cdef 'struct pollfd {int fd; short events; short revents;}'
cdef 'typedef unsigned long nfds_t'
cdef 'int poll (struct pollfd *fds, nfds_t nfds, int timeout)'
local pollfds = ffi.typeof 'struct pollfd[?]'
local fds
function ox.start(init)
  ox.on = true
  if init then init() end
  while ox.on do
    fds = pollfds(#contexts, contexts)
    if C.poll(fds, #contexts, 1000) > 0 then
      for i=0, #contexts -1 do
        if band(fds[i].revents, EV_IN) == EV_IN then print(i,'read')end
      end
    end
  end
end

-- AIO
--
function ox.fill(src, cb)
end
function ox.readln(src, max, cb)
end
function ox.read(src, n, cb)
end
function ox.write(des, n, cb)
end
function ox.transfer(des, src, n, cb)
end

-- TRANSPORT
--
function ox.tcpserv(port, cb)
end
function ox.tcpconn(host, port, cb)
end
function ox.unixserv(file, cb)
end
function ox.unixconn(file, cb)
end

local pfds = ffi.new 'int[2]'
local O_NONBLOCK = 2048
function ox.pipe(flag)
  local i
  if flag == 'rw' then
    i = C.pipe2(pfds, O_NONBLOCK)
  elseif flag =='r' then
    i = C.pipe(pfds)
    i = i~=-1 and C.fnctl(pfds[0], O_NONBLOCK)

end


-- LOOP
--

function ox.stop()
  ox.on = false
end

return ox
