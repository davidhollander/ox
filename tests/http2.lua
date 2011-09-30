local ox = require 'ox'
local http = require 'ox.http'
local PORT = 9090


print('1 readln, no parsing', PORT)
print(ox.tcpserv(PORT, function(c)
  return ox.readln(c, 2048, function(c, line)
    return ox.write(c, 'HTTP/1.1 200 OK\r\n\r\nHello World\r\n', ox.close)
  end)
end))

print('full parsing', PORT+1)
print(ox.tcpserv(PORT+2, function(c)
  return http.readreq(c, function(c)
    c.res = {jar={},head={}}
    return http.reply(c, 200, 'Hello World')
  end)
end))


print('fill parsing + routing', PORT+2)
http.route '*' '*' '*' (function(c)
  return c:reply(200, 'Hello World')
end)

print(ox.tcpserv(PORT+2, http.accept)) 

ox.start()
