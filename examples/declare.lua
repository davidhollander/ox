local ox = require 'ox'
local server = require 'ox.http.server'

ox.http(function(req, res)
  req.method = 'POST'
  req.path = '/'
  req.data(auth, true)

  res.status = 303
  res.head.Location = '/'
end)




-- require\assert request properties route
-- capture request variables
-- transform captured
ox.http(function(req)
  req.method = 'GET'
  req.path = '/'
  req.jar.u()
end
)

--problem: no seperate matching methods for path
ox.http 'localhost' 'GET' '/'

-- problem: no order for capturing args to pass to continuation
ox.http {path='/', method='GET', host='localhost'}
(function(res)
  if not session(cookie) then
    res.body = [[
    <h1>Login</h1>
    <form method="POST">
      <input type="text" name="user"/>
      <input type="submit"/>
    </form>]]
  else
    res.body = 'Welcome'
  end
end)


-- create a request matcher
local req = ox.request
req.data()


req(function(res, data)
  if auth(data) then
    res(303, {['Location'] = '/'})
  else
    res(200, nil, "Hello World")
  end
end)

ox('localhost', 'POST', '/')
ox('data', 100)


http('localhost','rofl')('GET','POST')('/')(function(c)
  
end)

ox.http {
  host = 'localhost',
  method = 'POST',
  path = '/',
  body_length = 100,

  function(req, res)
    if auth(data) then
      res.head.Location = '/'
      res.status = 303
    else
      res.body = 'Hello World'
    end
  end
}

ox.start()
