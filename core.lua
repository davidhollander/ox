-- ox.core
-- Copyright (c) 2011 David Hollander
-- Released under the simplified BSD license, see LICENSE.txt

-- An event loop and utility functions
local data=require'ox.data'
local nixio=require 'nixio'
local bcheck=nixio.bit.check
local bset=nixio.bit.set
local bunset=nixio.bit.unset
local EV_OUT=nixio.poll_flags('out')
local EV_IN=nixio.poll_flags('in')
local contexts={}
local on=true
local timers={}
local ti=table.insert
local tc=table.concat
module(... or 'ox.core',package.seeall)

time = os.time()
log = print

---Store errors in file instead of printing
function log_file(file)
  f=io.open(file,'a+')
  if f then
    log = function(...)
      f:write(table.concat{...})
      f:flush()
    end
  end
end


-- call [fn] in [sec] seconds.
-- Low accuracy. Might add something using nixio.ctime in future if needed.
function timer(fn, sec)
  ti(timers, {time=os.time()+sec,fn=fn})
  table.sort(timers, function(a,b) return a.time<b.time end)
end

-- tick
-- Fire timers if needed
local function tick()
  for i=#timers,1,-1 do
    local t=timers[i]
    if t.time>os.time() then break
    else t.fn(); timers[i]=nil end
  end
end

---Set the read callback for a connection table
function on_read(c,cb)
  c.events=bset(c.events,EV_IN)
  c.read=cb
end
---Set the write callback for a connection table
function on_write(c,cb)
  c.events=bset(c.events,EV_OUT)
  c.write=cb
end
---Clear the read callback for a connection table
function stop_read(c)
  c.events=bunset(c.events,EV_IN)
  c.read=nil
end
---Clear the write callback for a connection table
function stop_write(c)
  c.events=bunset(c.events,EV_OUT)
  c.write=nil
end

local global_events={}
function bind(name, fn)
  if global_events[name] then
    ti(global_events[name], fn)
  else global_events[name]={fn} end
end
function trigger(name)
  for i,fn in ipairs(global_events) do
    fn()
  end
end


---Start sending on next cycle, close when done
function finish(c, msg)
  local n=0
  on_write(c, function(c)
    n=n+c.fd:send(msg, n)
    if n>=#msg then
      c.fd:close()
      return 'close'
    end
  end)
end

---Send a chunk on every cycle starting with [head]
-- when [source] returns nil, send [foot] and close.
function finish_source(c, head, source, foot)
  local n=0
  local msg=head or source()
  on_write(c, function(c)
    n=n+c.fd:send(msg,n)
    if n==#msg then
      n=0
      msg=source()
      if not msg then
        c.fd:send(foot or '')
        c.fd:close()
        return 'close'
      end
    end
  end)
end
function send(c,msg)
  local n=0
  on_write(c, function(c)
    n=n+c.fd:send(msg, n)
    if n>=#msg then
      stop_write(c)
    end
  end)
end
--[[Send a message until done, checking for disconnects.
function send(c, msg, cb)
  local n=0
  on_write(c, function(c)
    local m = c.fd:send(msg, n)
    if m==nil then c.fd:close() return 'close', cb and cb()
    else
      n=n+m
      if n>=#msg then
        stop_write(c)
        return cb and cb(c)
      end
    end
  end)
end


function send_source(c, head, source, foot, cb)
  local n=0
  local msg = head or source()
  on_write(c, function(c)
    local m = c.fd:send(msg, n) or c.fd:close()
    if m==nil then return 'close', cb and cb()
    else
      n=n+m
      if n>=#msg then
        n=0
        msg = source()
        if not msg then
          c.fd:send(foot or '')
          stop_write(c)
          return cb and cb(c)
        end
      end
    end
  end)
end]]
---Buffer the ouput from a pipe, then passes to [cb]
function buffer_pipe(cb)
  local out={}
  return function (c)
    while true do
      local data = c.fd:read(8192)
      if data then table.insert(out,data)
      else
        c.fd:close()
        cb(table.concat(out))
        return 'close'
      end
    end
  end
end

---If already writing, put in outbox
-- Else start writing and check outbox when done
function push_send(c, chunk)
  if bcheck(c.events, EV_OUT) then
    if not c.outbox then c.outbox={chunk}
    else table.insert(c.outbox, chunk) end
  else
    local n=0
    local msg=chunk
    on_write(c,function(c)
      n=c.fd:send(msg,n)
      if n==#msg then
        if c.outbox then
          msg=table.concat(c.outbox)
          c.outbox=nil
          n=0
        else stop_write(c) end
      end
    end)
  end
end

---Fork and call [fn] outside of the event loop, pass result to [cb]
-- Result is a buffered string
function call_fork(fn, cb)
  local pipeout,pipein=nixio.pipe()
  pipeout:setblocking(false)
  local pid=nixio.fork()
  if pid==0 then
    pipein:write(tostring(fn()))
    pipein:close()
    os.exit()
  else
    table.insert(contexts,{
      fd=pipeout,
      events=EV_IN,
      revents=0,
      accept_time=time+10,
      read=buffer_pipe(cb)
    })
  end
end

-- asynchronous DNS lookup pooler and cache
local host_cache = data.cache_table(function(host, cb)
  call_fork(function()
    local x = nixio.getaddrinfo(host, 'inet', port)
    return x and x[1].address or nil
  end, cb)
end, 1000)

---Create a connection to [host] on [port] and pass to [cb]
-- If [host] is not an ip address, fork and wait for DNS loopup, then cache ip
function connect(host, port, cb)

  local function _connect(ip, port, cb)
    local sock, e, m = nixio.socket('inet','stream')
    print('connect', sock, e, m)
    if sock then
      sock:setblocking(false)
      sock:connect(ip, port)
      local c={fd=sock,events=0,revents=0}
      table.insert(contexts, c)
      cb(c)
      return true
    else return nil, e, m end
  end

  local ip = host:match('^%d+\.%d+\.%d+\.%d+$')
  if ip then return _connect(ip, port, cb)
  else
    host_cache(host, function(ip) print(ip) _connect(ip, port, cb) end)
  end
end

---Run a tcp server on [port] that passes each accepted client to [cb]
function serve(port, cb)
  local sock, e, m = nixio.bind('*', port)
  if sock then
    sock:setblocking(false)
    sock:listen(1024)
    table.insert(contexts, {
      fd = sock,
      events = EV_IN,
      revents = 0,
      read = function(server)
        while true do
          local sock = server.fd:accept()
          if sock then
            local c={fd=sock,events=0,revents=0,accept_time=time}
            cb(c)
            table.insert(contexts,c)
          else break end
        end
      end
    })
    return true
  else return nil,e,m end
end

-- expire
-- Close accepted connections older than [timeout]
function expire(timeout)
  local old = time - timeout
  local oldcontexts=contexts
  contexts={}
  local brk=false
  for i=1,#oldcontexts do
    if brk then contexts[i]=oldcontexts[i]
    else
      local c=oldcontexts[i]
      if not c.accept_time then table.insert(contexts,c)
      elseif c.accept_time<old then c.fd:close(); log('expired')
      else brk=true; table.insert(contexts,c) end
    end
  end
end

---break server loop
function stop() on=false end

---Starts main event loop. Times out generated connections after 20 seconds.
function loop(timeout)
  while on do
    local stat, code = nixio.poll(contexts, 500)
    time=os.time()
    if stat and stat>0 then
      local oldcontexts=contexts
      contexts={}
      for i=1,#oldcontexts do
        local c=oldcontexts[i]
        if bcheck(c.revents,EV_OUT) and c:write()=='close'
          or bcheck(c.revents,EV_IN) and c:read()=='close' then
            --c.fd:close()
        else
          c.revents=0 
          table.insert(contexts,c)
        end
      end
    end
    expire(timeout or 20)
    tick()
  end
end
