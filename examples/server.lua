local ox = require 'ox'
local server = require 'ox.http.server'

local function handler(t)
  return ox(ox.proto({host = 'localhost', port = 80}, t))
end


handler {
  method = 'POST',
  path = '/upload',
  session,
  function(req, res)
    res.body = "Hello World"
    res()
  end
}

handler {
  method = 'POST',
  path = '/upload',
  bodymax = 1024,
  filesmax = 3,
  jar = {u=true},

  function(req, res)
    req.jar.u
  end,
}

ox.http(function(req, res)
  req.method = 'GET'
  req.path = '/'
 
  res.data = function(data) end
  res.status = 303
  res.head.Location = '/'
end)

ox.http(function(req, res)
  req.method = 'POST'
  req.path = '/'
  req.data(auth, true)

  res.status = 303
  res.head.Location = '/'

end)
ox.http(function(req, res)
  req.method = 'GET'
  req.path = '/'
  req.path_match = '/hello/([^/]+)'
end)

local req = ox.http()

req.method = 'GET'
req.path = match '/user/([^/]+)'
req.body = buffer(1024)

req.head.Accept = true
req.head['Accept-Language'] = true

req[1] = function(accept, lang)
  return 'hello world'
end


ox.start()
