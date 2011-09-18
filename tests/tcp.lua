local ox = require 'ox'
local PORT = 8096
print('start', PORT)
print(ox.tcpserv(PORT, ox.close))
ox.start()
