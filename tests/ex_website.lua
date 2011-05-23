package.path = package.path..';./../?.lua'
local core = require 'ox.core'
local http = require 'ox.http'
local file = require 'ox.file'
local json = require 'json'


http.GET['^/file$'] = file.CacheSingle('file.html')

-- Serving content
http.GET['^/$'] = function(c)
  http.SetHeader(c,'Content-Type','text/html')
  http.RespondFixed(c, 200, [[
    <form method="POST">
      <input type="text" name="user"/>
      <input type="password" name="pw"/>
      <input type="submit" value="login"/>
    </form>]])
end

-- Serving dynamic content
http.GET['^/hello/(.*)$'] = function(c, capture)
  http.SetHeader(c, 'Content-Type', 'text/plain')
  http.RespondFixed(c, 200, 'Welcome, '..capture)
end

-- Handling form POST
http.POST['^/$'] = function(c)
  local d=c.req.data
  if d.user=="lua" and d.pw=="ox" then
    http.SetHeader(c,'Location', '/redirected')
    http.Respond(c, 303)
  else
    http.SetHeader(c, 'Content-Type', 'text/html')
    http.Respond(c, 200, "Could not login")
  end
end

http.GET['/redirected'] = function(c)
  http.SetHeader(c,'Content-Type', 'text/html')
  http.Respond(c, 200, "Success, you have been redirected.")
end

-- Serving JSON
http.GET['^/json$'] = function(c)
	http.SetHeader(c, 'Content-Type', 'application/json')
	http.Respond(c, 200, json.encode{name="foo", message="hello world"})
end

http.Server(8080, http)
print("server on 8080")
core.Loop()
