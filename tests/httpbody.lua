local ox = require 'ox'
local http = require 'ox.http'
local PORT = ... or 8080

http.route '*' '*' '/chunked' (function(c)
  http.writehead(c, function(c)
    http.write(c, 'Chunk1', function(c)
      http.write(c, 'Chunk2', http.close)
    end)
  end)
end)

http.fetch({port=PORT, path='chunked'}, function(c)
  return http.readbody(c, 2048, 0, function(c, body)
    assert(body='Chunk1Chunk2')
  end)
end)

ox.tcpserv(PORT, http.accept)
ox.start()
