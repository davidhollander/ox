local ox = require 'ox'
local PORT = 8095
print('start', PORT)
print(ox.tcpserv(PORT, function(c)
  ox.fill(c, ox.close)
end))
ox.start()
