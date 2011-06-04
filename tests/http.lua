local core = require 'ox.core'
local nixio = require 'nixio'
tests={}

tests.server = function()
  local request = "GET / HTTP/1.1\r\n\r\n"
  local http = require 'ox.http'
  http.GET['^/$'] = function(c)
    assert(c.
    core.Stop()
  end
  http.Server(8080, http)
  nixio.connect( 
  core.Loop()
end

tests.int_client = function()
  http. 
  http.server(8080, http)
  core.loop()
end
