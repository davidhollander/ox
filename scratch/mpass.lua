-- mpass.lua
-- A message passing addon for ox for shared nothing architecture

local core= require'ox.core'
local addresses={}
local connections={}


function interpret(msg)
  msg:
end
-- A basic parser that buffers a stream of bytes into chunks seperated by '.'
function makechunks(cb)
  local buffer={}
  return function(bytes)
    local i = bytes:find('\r\n')
    if not i then
      table.insert(buffer, bytes)
    elseif bytes:sub(#bytes)=='\r' then
      table.insert(buffer, bytes:sub(1, #bytes-1))
    else
      table.insert(buffer, bytes:sub(1, r-1))
      cb(table.concat(buffer))
      buffer={bytes:sub(r+1, #bytes)}
    end
  end
end


-- Create a message server on port
function Server(port, name, views)
  return core.Serve(port, function(c)

    local parser = makeparser(function(msg)
    end)

    OnRead(c, function(c)
      parser(c)
    end)
    
  end)
end


function Client(address, msg)

end
