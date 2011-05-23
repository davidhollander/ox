-- ox.core
-- Copyright (c) 2011 David Hollander
-- Released under the simplified BSD license, see LICENSE.txt

-- An event loop and utility functions

local nixio=require 'nixio'
local bcheck=nixio.bit.check
local bset=nixio.bit.set
local bunset=nixio.bit.unset
local EV_OUT=nixio.poll_flags('out')
local EV_IN=nixio.poll_flags('in')
local contexts={}
local on=true
local timers={}

module('ox.core',package.seeall)

time = os.time()
Log = print

-- LogFile
-- Store errors in file instead of printing
function LogFile(file)
  f=io.open(file,'w')
  if f then
    Log = function(...)
      f:write(table.concat{...})
      f:flush()
    end
  end
end

-- Trigger
-- call [fn] in [sec] seconds.
-- Low accuracy. Might add something using nixio.ctime in future if needed.
function Trigger(fn, sec)
	table.insert(timers,{time=time+sec,fn=fn})
	table.sort(timers, function(a,b) return a.time<b.time end)
end

-- Tick
-- Fire timers if needed
-- Popping from beginning is innefficient will prob reimplement
local function tick()
	for i=1,#timers do
		local t=timers[1]
		if t.time>=time then break
		else t.fn(); table.remove(timers,1) end
	end
end

-- OnRead, OnWrite, StopRead, StopWrite
-- Set or clear the read and write callback
function OnRead(c,cb)
  c.events=bset(c.events,EV_IN)
  c.read=cb
end
function OnWrite(c,cb)
  c.events=bset(c.events,EV_OUT)
  c.write=cb
end
function StopRead(c)
  c.events=bunset(c.events,EV_IN)
  c.read=nil
end
function StopWrite(c)
  c.events=bunset(c.events,EV_OUT)
  c.write=nil
end

-- SendEnd
-- Start sending on next cycle, Close when done
function SendEnd(c, msg)
  local n=0
  OnWrite(c,function(c)
    n=n+c.fd:send(msg,n)
    if n>=#msg then
      c.fd:close()
      return 'close'
    end
  end)
end

-- SendReq
-- Send a message until done, checking for disconnect.
function SendReq(c, msg, cb)
	local n=0
	OnWrite(c, function(c)
		local m = c.fd:send(msg, n)
		if not m then
			if cb then cb(false) end
			c.fd:close() return 'close'
		end
		n=n+m
		if n==#msg then
			StopWrite(c)
			if cb then cb(c) end
		end
	end)
end

-- SendSourceEnd
-- Send a chunk on every cycle starting with [head]
-- when [source] returns nil, send [foot] and close.
function SendSourceEnd(c, head, source, foot)
  local n=0
  local msg=head or source()
  OnWrite(c, function(c)
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

-- BufferPipe
-- Buffer the ouput from a pipe, then passes to [cb]
function BufferPipe(cb)
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

-- SendQueue
-- If already writing, put in outbox
-- Else start writing and check outbox when done
function SendQueue(c, chunk)
  if bcheck(c.events,EV_OUT) then
    if not c.outbox then c.outbox={chunk}
    else table.insert(c.outbox,chunk) end
  else
    local n=0
    local msg=chunk
    OnWrite(c,function(c)
      n=c.fd:send(msg,n)
      if n==#msg then
        if c.outbox then
          msg=table.concat(c.outbox)
          c.outbox=nil
          n=0
        else StopWrite(c) end
      end
    end)
  end
end

-- CallFork
-- Fork and call [fn] outside of the event loop, pass result to [cb]
-- Result is a buffered string
function CallFork(fn, cb)
  local pipeout,pipein=nixio.pipe()
	print(pipeout:setblocking(false))
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
			accept_time=time,
      read=BufferPipe(cb)
		})
  end
end

-- Connect
-- Create a connection to [host] on [port] and pass to [cb]
-- If [host] is not an ip address, fork and wait for DNS loopup, then cache ip
local host_cache={}
function Connect(host, port, cb)
	
	local function _connect(ip, port, cb)
		local sock = nixio.socket('inet','stream')
		sock:setblocking(false)
		sock:connect(ip, port)
		local c={fd=sock,events=0,revents=0}
		table.insert(contexts, c)
		cb(c)
		return true
	end

	local ip = host:match('^%d+\.%d+\.%d+\.%d+$') or host_cache[host]
  if ip then return _connect(ip, port, cb)
	else
		CallFork(function()
				local x = nixio.getaddrinfo(host, 'inet', port)
				return x and x[1].address or nil
			end,
			function(ip)
				host_cache[host]=ip
				_connect(ip, port, cb)
		end)
	end
end

-- Serve
-- Run a tcp server on [port] that passes each accepted client to [cb]
function Serve(port, cb)
  local sock = nixio.bind('*', port)
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
  else return false end
end

-- Expires
-- Close accepted connections older than [timeout]
function Expire(timeout)
	local old = time - timeout
	local oldcontexts=contexts
	contexts={}
	local brk=false
	for i=1,#oldcontexts do
		if brk then contexts[i]=oldcontexts[i]
		else
			local c=oldcontexts[i]
			if not c.accept_time then table.insert(contexts,c)
			elseif c.accept_time<old then c.fd:close(); print('expired')
			else brk=true; table.insert(contexts,c) end
		end
	end
end

-- Stop: break server loop
function Stop() on=false end

-- Loop
-- Starts main event loop with optional [times] callback table
function Loop()
  while on do
    local stat, code = nixio.poll(contexts,500)
		time=os.time()
    if stat and stat>0 then
      local oldcontexts=contexts
      contexts={}
      for i=1,#oldcontexts do
        local c=oldcontexts[i]
        if bcheck(c.revents,EV_OUT) and c.write(c)=='close'
          or bcheck(c.revents,EV_IN) and c.read(c)=='close' then
          --c.close(c)
        else
          c.revents=0 
          table.insert(contexts,c)
        end
      end
    end
		Expire(20)
  end
end
