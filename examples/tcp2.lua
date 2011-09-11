local ox=require'ox'
local PORT = 8095
local ti, tc = table.insert, table.concat

local function response(line)
  return tc {'HTTP/1.1 200 OK\r\n\r\n',line,'\r\n'}
end

ox.tcpserv(PORT, function(c)
  ox.readln(c, 2048, function(line)
    ox.write(c, response(line), ox.close)
  end)
end)

print(PORT)

ox.start()
