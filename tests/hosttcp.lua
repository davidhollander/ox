local ox = require 'ox'

function handle(c, err)
  print('handle', c, err)
  ox.stop()
end

ox.tcpconn('google.com', 80, handle)

ox.start()
