-- ox.http
-- Copyright (c) 2011 David Hollander
-- Released under the simplified BSD license, see LICENSE.txt

-- an http server and utility functions

local core=require 'ox.core'
local tc = table.concat
local ti = table.insert
module(... or 'ox.http',package.seeall)

status_line={
  [200]="HTTP/1.1 200 OK\r\n",
  [201]="HTTP/1.1 201 Created\r\n",
  [206]="HTTP/1.1 206 Partial Content\r\n",
  [303]="HTTP/1.1 303 See Other\r\n",
  [400]="HTTP/1.1 400 Bad Request\r\n",
  [401]="HTTP/1.1 401 Unauthorized\r\n",
  [404]="HTTP/1.1 404 Not Found\r\n",
  [500]="HTTP/1.1 500 Internal Server Error\r\n",
}
GET,PUT,POST,DELETE={},{},{},{}

-- url_decode, url_encode
-- from WSAPI https://github.com/keplerproject/wsapi/blob/master/src/wsapi/request.lua
function url_decode(str)
  if not str then return nil end
  str = string.gsub (str, "+", " ")
  str = string.gsub (str, "%%(%x%x)", function(h) return string.char(tonumber(h,16)) end)
  str = string.gsub (str, "\r\n", "\n")
  return str
end
function url_encode(str)
  if not str then return nil end
  str = string.gsub (str, "\n", "\r\n")
  str = string.gsub (str, "([^%w ])",
        function (c) return string.format ("%%%02X", string.byte(c)) end)
  str = string.gsub (str, " ", "+")
  return str
end

-- qs_decode
-- Parses query strings and forms
function qs_decode(qstr)
  local t={}
  for k,v in string.gmatch(qstr, "([^&=]+)=([^&=]*)&?") do
    if #v>0 then t[url_decode(k)] = url_decode(v)
    else t[url_decode(k)] = true end
  end
  return t
end

url = url_encode
-- escapes html characters
function html(text)
  return string.gsub(text or '',"[&<>'\"]",{
    ['&']="&amp;",
    ['<']="&lt;",
    ['>']="&gt;",
    ["'"]="&#39;",
    ['"']="&quot;"
  })
end

-- chunkwrap(source)
-- transforms the output of a function to HTTP Chunked encoding
function chunkwrap(source)
  return function()
    local m=source()
    return table.concat{string.format('%x',#m),'\r\n',m,'\r\n'}
  end
end

-- reply(c, status, body)
-- Send an HTTP response and close connection when done.
-- [body] can be nil, a string, or a function.
-- If a function, the response ends when [body] returns 'nil'.
function reply(c, status, body)
  local s = status_line[status]
  if not s then return http.err(c) end
  local t = {status_line[status]}
  for k,v in pairs(c.res.head or {}) do
    ti(t, k) ti(t, ':  ') ti(t, v) ti(t, '\r\n')
  end
  for k,v in pairs(c.res.cookie or {}) do
    ti(t, 'Set-Cookie: ') ti(t, k) ti(t, v) ti(t, '\r\n')
  end
  if type(body)=='function' then
    if not c.res.head['Content-Length'] then
      ti(t, 'Transfer-Encoding: chunked\r\n\r\n')
      body=chunkwrap(body)
    end
    return core.finish_source(c, table.concat(t), body, '\r\n')
  elseif type(body)=='string' then
    ti(t, 'Content-Length: ') ti(t, #body) ti(t, '\r\n\r\n') ti(t, body) ti(t, '\r\n')
    return core.finish(c, table.concat(t))
  else return core.finish(c, table.concat(t)) end
end

-- reply_json(c, status, body)
-- shortcut for sending json
function reply_json(c, status, body)
  c.res.head['Content-Type']='application/json'
  return reply(c, status, json.encode(body))
end

-- datetime(utcseconds)
-- converts a date into a string appropriate for a HTTP header
-- ex: Wed, 09 Jun 2021 10:18:14 GMT
function datetime(utcseconds)
  return os.date('!%a, %d %b %Y %H:%M:%S %Z',utcseconds)
end

-- header(c, key, [value])
-- get or set a header for context [c]
function header(c, key, value)
  if not value then return c.req.head[key]
  else c.res.head[key]=value; return true end
end

-- cookie(c, key, [value])
-- get or set a cookie for context [c]
-- ex: c:cookie('message','hello; path=/; httponly')
function cookie(c, key, value)
  if not value then return c.req.head.Cookie:match(key..'=(%w+)')
  else c.req.cookie[key]=value; return true end
end

local web_methods={
  cookie=cookie,
  header=header,
  reply=reply,
}

-- web(c): optional middleware for wrapping contexts with helpers
function web(c) return setmetatable(c, methods) end

-- Server
-- Create a server on [port] using [views]
-- [views] contains a subtable for each HTTP method.
-- Each HTTP method table contains url patterns mapped to functions.

function Server(port,views,mware)
  return core.Serve(port,function(c)
    c.req={head={}}
    local req, done, buffer = c.req, false, {}
    local function complete() end
    local parser=lhp.request{
      on_url=function(url) req.url=url end,
      on_path=function(path) req.path=path end,
      on_header=function(key,val) req.head[key]=val end,
      on_query_string=function(qstr) req.qstr=qs_decode(qstr) end,
      on_fragment=function(frag) req.frag=frag end,
      on_body=function(body) table.insert(buffer, body) end,
      on_message_complete=function()
        req.body=table.concat(buffer)
        local d=decoders[req.head['Content-Type']]
        if d then req.data = d(req.body) end
        done=true
      end,
      on_headers_complete=function()
        local cl=c.req.head['Content-Length']
        local te=c.req.head['Transfer-Encoding']
        if cl and cl>8192 or te and te=='chunked' then done=true end
        local ct=c.req.head['Content-Type']
        if ct~="application/x-www-form-urlencoded" then done=true end
      end
    }
    core.OnRead(c,function(c)
      local data=c.fd:recv(1024)
      if data==false then return 
      elseif data==nil or data=='' or parser:execute(data)==0 then
        c.fd:close()
        return 'close'
      elseif done then
        if mware then for i=1,#mware do mware[i](c) end end
        local capture
        for path,fn in pairs(views[parser:method()]) do
          capture=req.path:match(path)
          if capture then
            local success,err=pcall(fn,c,capture)
            if not success then Respond(c, 500, err); core.Log(500,err) end
            break
          end
        end
        if not capture then Respond(c, 404) end
      end
    end)
  end)
end

local decoders={
  ['application/x-www-form-urlencoded']=qs_decode,
  ['application/json']=json.decode,
}
-- client
-- Make an asynchronous HTTP Request and buffer response body
-- on_message_complete callback is not getting triggered for some reason
function client(req, cb)
  return core.connect(req.host, req.port or 80, function(c)
    if not req.head or not req.head.Host then
      req.head.Host=req.host
    end
    local t={req.method or 'GET',' ',req.path or '/'," HTTP/1.1\r\n"}
    for k,v in pairs(req.head or {}) do
      table.insert(t, k..': '..v..'\r\n')
    end
    if req.cookie then 
      ti(t, 'Cookie: ')
      for k,v in pairs(req.cookie) do
        ti(t, k) ti(t, '=') ti(t, v) ti(t, ';')
      end
      ti(t, '\r\n')
    end
    if type(req.body)=='function' then
      if not req.head['Content-Length'] then
        ti(t, 'Transfer-Encoding: chunked\r\n\r\n')
        body=chunkwrap(body)
      end
      return core.finish_source(c, table.concat(t), body, '\r\n')
    elseif type(body)=='string' then
      ti(t, 'Content-Length: ') ti(t, #body) ti(t, '\r\n\r\n') ti(t, body) ti(t, '\r\n')
      return core.finish(c, table.concat(t))
    else return core.finish(c, table.concat(t)) end

    local res={headers={},body={}}
    local done=false
    local parser=lhp.response{
      on_header=function(key,val) res.headers[key]=val end,
      on_body=function(chunk,e) table.insert(res.body,chunk) end,
      on_message_complete=function() done=true end,
      on_headers_complete=function() end,
    }
    core.on_read(c,function(c)
      local data=c.fd:recv(8192)
      if data==false then return 
      elseif data==nil or data=='' or parser:execute(data)==0 or done then
        res.status=parser:status_code();
        res.body=table.concat(res.body)
        c.fd:close()
        cb(res)
        return 'close'
      end
    end)
  end)
end
