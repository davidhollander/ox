
-- Spawn (NOT IMPLEMENTED)
-- Create a pool of preforked workers
local spawned={}
function Spawn(n)
  function spawnone()
    local pipeout,pipein=nixio.pipe()
    local pid=nixio.fork()
    if pid==0 then
      table.insert(c,{fd=pipeout,events=0,revents=0})
      Loop()
    else
      table.insert(c,{fd=pipein,events=0,revents=0})
    end
  end
end


-- SendA 
-- Star this cycle, if not complete continue on next cycle
-- Run cb when done
function SendA(c,msg)
  local n=c.fd:send(msg,0)
  if n<#msg then
    OnWrite(c,function(c)
      m=c.fd:send(msg,n)
      n=n+m
      if n==#msg then c.fd:close() return 'close'  end
    end)
  else c.fd:close() return 'close' end
end

-- SendSourceOld
-- Start sending next cycle, 1 chunk at a time
-- Close when source returns nils
local function SendSourceOld(c,source)
  local n=0
  local msg=source()
  OnWrite(c,function(c)
    n=n+c.fd:send(msg,n)
    if n==#msg then
      n=0
      msg=source()
      if not msg then
        c.fd:send('\r\n')
        c.fd:close()
        return 'close'
      end
    end
  end)
end
-- Spawn (NOT IMPLEMENTED)
-- Create a pool of preforked workers
local spawned={}
function Spawn(n)
  function spawnone()
    local pipeout,pipein=nixio.pipe()
    local pid=nixio.fork()
    if pid==0 then
      table.insert(c,{fd=pipeout,events=0,revents=0})
      Loop()
    else
      table.insert(c,{fd=pipein,events=0,revents=0})
    end
  end
end

