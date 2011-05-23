-- ox.rpc
-- Copyright (c) 2011 David Hollander
-- Released under the simplified BSD license, see LICENSE.txt

local core=require'ox.core'
module('ox.rpc',package.seeall)

parse_call=function(cb)
  local prev=false
  return function(chunk)
    if not prev then
      prev=chunk
    else
      cb(prev,chunk)
      prev=false
    end
  end
end

parse_transport=function(cb)
  local buffer={}
  return function(bytes)
    local r=bytes:find("\r\n")
    if not r then
      table.insert(buffer,bytes)
    else
      table.insert(buffer,bytes:sub(1,r-1))
      cb(table.concat(buffer))
      buffer={bytes:sub(r+2,#bytes)}
    end
  end
end

function Call(c,name,data,cb)
  local request=table.concat{name,'\r\n',data,'\r\n'}
  local key=hash(request)
  local t=c.callbacks[key]
  if t then table.insert(t,cb)
  else c.callbacks[key]={cb} end
  table.insert(c.outbox,req)
end

function Connect(host,port,views)
  local function response(chunk1,chunk2)
    for i,fn in ipairs(callbacks[chunk1]) do
      fn(chunk2)
    end
  end
  local parser=parse_transport(parse_call(response))
  return core.Connect(host,port,function(c)
    core.OnRead(c,function(c)
      local data=thread.fd:recv(1024)
      if data==false then return
      elseif data==nil or data=='' then return 'close'
      else parser(data) end
    end)
  end)
end

function Server(port,views)
  local function receive(chunk1,chunk2)
    local v=views[chunk1]
    if not v then
  return core.Serve(port,function(thread)
    local parser=parse_transport(parse_call(receive))
    OnRead(thread,function(thread)
      local data=thread.fd:recv(1024)
      if data==false then return 
      elseif data==nil or data=='' then return 'close'
      else parser(data) end
    end)
  end)
end
