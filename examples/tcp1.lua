-- tcp1.lua
-- Returns the first request line as an HTTP response

local ox=require'ox'
local PORT = 8093
local ti, tc = table.insert, table.concat

local function response(line)
  return tc {'HTTP/1.1 200 OK\r\n\r\n',line,'\r\n'}
end


local function handle(c, line)
  print(line)
  return ox.write(c, response(line), ox.close)
end


assert(ox.tcpserv(PORT, function(c)
  return ox.readln(c, 2048, handle)
end))

print(PORT)

ox.start()
