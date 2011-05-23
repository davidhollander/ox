package.path = package.path..';./../?.lua'
local core = require 'ox.core'
local http = require 'ox.http'
local file = require 'ox.file'

-- Hosting files
http.GET['^/static/(.*)'] = file.SimpleHandler('/home/david/doc/notes/')

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
  if d.user=="hacker" and d.pw=="news" then
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

-- Handling file upload
http.GET['^/upload$'] = function(c)
  http.SetHeader('Content-Type', 'text/html')
  http.Respond(c, 200, [[
    <form method="POST">
      <input type="file" name="file1"/>
      <input type="file" name="file2"/>
      <input type="submit" value="upload"/>
    </form>
    ]])
end

-- Saving uploaded file
http.POST['^/upload$'] = function(c)
  local name=d.name
  http.StoreUpload(c,'upload/'..test,function(status)
    if status then
      http.FileResponse(c, io.open('upload/'..test))
    else
      http.Respond(c, 200, "Upload failed")
    end
  end)
end

-- Serving JSON
http.GET['^/json$'] = function(c)
	http.SetHeader('Content-Type', 'application/json')
	http.Respond(c, 200, json.encode{name="foo", message="hello world"})
end

http.Server(8080, http)
print("server on 8080")
core.Loop()
