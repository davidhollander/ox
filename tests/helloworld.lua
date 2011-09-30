local ox = require'ox'
local PORT = 9094
print(PORT)
print(ox.tcpserv(PORT, function(c)
  return ox.readln(c, 2048, function(c, line)
    return ox.write(c, 'HTTP/1.1 200 OK\r\n\r\nHello World\r\n', ox.close)
  end)
end))

ox.start()
