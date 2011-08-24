-- ox.http
-- Copyright (c) 2011 David Hollander
-- Released under the simplified BSD license, see LICENSE.txt

-- an http server and utility functions

local core=require 'ox.core'
local ti, tc = table.insert, table.concat
module(... or 'ox.http',package.seeall)

status_line={
  [100]="HTTP/1.1 100 Continue\r\n",
  [101]="HTTP/1.1 101 Switching Protocols\r\n",
  [200]="HTTP/1.1 200 OK\r\n",
  [201]="HTTP/1.1 201 Created\r\n",
  [202]="HTTP/1.1 202 Accepted\r\n",
  [203]="HTTP/1.1 203 Non-Authoritative Information\r\n",
  [204]="HTTP/1.1 204 No Content\r\n",
  [205]="HTTP/1.1 204 Reset Content\r\n",
  [206]="HTTP/1.1 206 Partial Content\r\n",
  [300]="HTTP/1.1 300 Multiple Choices\r\n",
  [301]="HTTP/1.1 301 Moved Permanently\r\n",
  [303]="HTTP/1.1 303 See Other\r\n",
  [304]="HTTP/1.1 304 Not Modified\r\n",
  [307]="HTTP/1.1 307 Temporary Redirect\r\n",
  [400]="HTTP/1.1 400 Bad Request\r\n",
  [401]="HTTP/1.1 401 Unauthorized\r\n",
  [403]="HTTP/1.1 403 Forbidden\r\n",
  [404]="HTTP/1.1 404 Not Found\r\n",
  [405]="HTTP/1.1 405 Method Not Allowed\r\n",
  [406]="HTTP/1.1 406 Not Acceptable\r\n",
  [407]="HTTP/1.1 407 Proxy Authentication Required\r\n",
  [408]="HTTP/1.1 408 Request Timeout\r\n",
  [409]="HTTP/1.1 409 Conflict\r\n",
  [410]="HTTP/1.1 410 Gone\r\n",
  [411]="HTTP/1.1 411 Length Required\r\n",
  [412]="HTTP/1.1 412 Precondition Failed\r\n",
  [413]="HTTP/1.1 413 Request Entity Too Large\r\n",
  [414]="HTTP/1.1 414 Request URI Too Long\r\n",
  [415]="HTTP/1.1 415 Unsupported Media Type\r\n",
  [416]="HTTP/1.1 416 Request Range Not Satisfiable\r\n",
  [417]="HTTP/1.1 417 Expectation Failed\r\n",
  [418]="HTTP/1.1 418 I'm a teapot\r\n", -- win.
  [500]="HTTP/1.1 500 Internal Server Error\r\n",
  [501]="HTTP/1.1 501 Not Implemented\r\n",
  [502]="HTTP/1.1 502 Bad Gateway\r\n",
  [503]="HTTP/1.1 503 Service Unavailable\r\n",
  [504]="HTTP/1.1 504 Gateway Timeout\r\n",
  [505]="HTTP/1.1 505 HTTP Version Not Supported\r\n",
}

hosts = {}

-- from WSAPI https://github.com/keplerproject/wsapi/blob/master/src/wsapi/request.lua
--- Decode a url string
function url_decode(str)
  if not str then return nil end
  str = string.gsub (str, "+", " ")
  str = string.gsub (str, "%%(%x%x)", function(h) return string.char(tonumber(h,16)) end)
  str = string.gsub (str, "\r\n", "\n")
  return str
end

--make sure to leave '.','-','~','_' as is
--- Encode a url string
function url_encode(str)
  if not str then return nil end
  str = string.gsub (str, "\n", "\r\n")
  str = string.gsub (str, "([^%w%.%-~_ ])",
        function (c) return string.format ("%%%02X", string.byte(c)) end)
  str = string.gsub (str, " ", "+")
  return str
end

--- Parse query string or form body
-- @param qstr string
-- @return table
function qs_decode(qstr)
  local t={}
  for k,v in string.gmatch(qstr, "([^&=]+)=([^&=]*)&?") do
    if #v>0 then t[url_decode(k)] = url_decode(v)
    else t[url_decode(k)] = true end
  end
  return t
end

--- Encode query string or form body
-- @param table
-- @return string
function qs_encode(t)
  local out={}
  for k,v in pairs(t) do
    if v~=true then
      ti(out, tc{url_encode(k),'=',url_encode(v)})
    else ti(t, k) end
  end
  return tc(out, '&')
end


url = url_encode
--- Escape html characters
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
local function chunkwrap(source)
  return function()
    if source then
      local m=source()
      if m then return tc{string.format('%x', #m), '\r\n', m, '\r\n'}
      else source=nil; return '0\r\n' end
    end
  end
end

function server_error(c, err)
  core.log('500',err)
  return core.finish(c, tc{status_line[500],'\r\n',err,'\r\n'})
end

---Send an HTTP response and close connection when done.
--@param c table. The connection this applies to.
--@param status number. The HTTP status code.
--@param body nil, string, or function. The response body. If a function, the response ends when [body] returns nil
function reply(c, status, body)
  --print('reply',status)
  local s = status_line[status]
  if not s then return server_error(c,'Bad response status: '..status) end

  local t = {status_line[status]}
  for k,v in pairs(c.res.head or {}) do
    ti(t, k); ti(t, ':  '); ti(t, v); ti(t, '\r\n')
  end
  for k,v in pairs(c.res.jar or {}) do
    ti(t, 'Set-Cookie: ') ti(t, k); ti(t, '='); ti(t, v); ti(t, '\r\n')
  end
  if type(body)=='function' then
    if not c.res.head['Content-Length'] then
      ti(t, 'Transfer-Encoding: chunked\r\n')
      body=chunkwrap(body)
    end
    ti(t, '\r\n')
    return core.finish_source(c, tc(t), body, '\r\n')
  elseif type(body)=='string' then
    ti(t, 'Content-Length: ') ti(t, #body) ti(t, '\r\n\r\n') ti(t, body) ti(t, '\r\n')
    return core.finish(c, tc(t))
  else return core.finish(c, tc(t)) end
end

---converts a date into a string appropriate for a HTTP header
-- ex: Wed, 09 Jun 2021 10:18:14 GMT
function datetime(utcseconds)
  return os.date('!%a, %d %b %Y %H:%M:%S %Z', utcseconds)
end
local decoders={
  ['application/x-www-form-urlencoded']=qs_decode,
  --['application/json']=json.decode,
}
---Add a server. Automatically routes accepted connections to handler functions placed in the
-- http.GET, http.PUT, http.POST, and http.DELETE method tables using a lua pattern string for keys.
-- @param port port number to listen on
-- @param mware List of functions to pass the connection table through before calling a handler. Optional
-- @return True or nil, Error Message.
function serve(port, mware)
  local mware = mware or {} 

  local function route(c)
    print 'route'
    --for i, v in ipairs(mware) do v(c) end
    local h
    local rh = c.req.head.Host
    if rh then
      for k,v in pairs(hosts) do
        if c.req.head.Host:match(k) then h=v; break end
      end
    end
    if not h then return reply(c, 404) end

    local m = h[c.req.method]
    if not m then return reply(c, 405) end

    local p = c.req.path
    for k,v in pairs(m) do
      local capture = {p:match(k)}
      if #capture>0 then
        local success, err = pcall(v, c, unpack(capture))
        if not success then return server_error(c, err) end return
      end
    end
    return reply(c, 404)
  end

  local function head(c, line)
    if not line then return reply(c, 413)
    elseif line=='' then return route(c) end
    --print('PARSE header',line)
    local key, val = line:match '^([^%s:]+)%s?:%s*(.+)'
    if not key then return reply(c, 400)
    elseif key=='Cookie' then
      for k,v in val:gmatch('([^;=%s]+)=([^;=%s]+)') do
        c.req.jar[k]=v
      end
    else c.req.head[key]=val end
    return core.readln(c, 2048, head)
  end
 
  local _methods = {GET=true,POST=true,PUT=true,DELETE=true}
  local function status(c, line)
    if not line then return reply(c, 414) end
    local method, path = line:match('(%w+) ([^%s]+) HTTP/1%.%d$')
    if not _methods[method] then c.fd:close(); c.closed=true return
    else c.req.method=method; c.req.path=path; return core.readln(c, 2048, head) end
  end

  return core.serve(port, function(c)
    c.req = {head={},jar={}}
    c.res={head={},jar={}}
    c.reply = reply
    core.readln(c, 2048, status)
  end)
end

function readbody(maxfiles, maxsize, decoders, cb)

  local function chunkend(c)
    c.data = tc(c.chunks)
  end

  local function chunk(c, data)
    ti(c.chunks, data)
    return core.read(c, 30, chunklen)
  end

  local function chunklen(c, line)
    local len = tonumber(line, 16)
    if len then return core.read(c, len, chunk) end
  end

  local function field(c, line)
    local d = c.data[#c.data]

    if line=='' then return core.read(c, len, file) end
    local key, val = line:match('^([%w_%-])+ ?: ?([%w_%-]+)$')
    if key=='Content-Type' then d.ct=val
    elseif key=='Content-Disposition' then d.cd=val end
  end

  local function boundary(c, line)
    if line==c.bdr then
      ti(c.data, {})
      return core.readln(c, 2048, field)
    end
  end

  return function(cb)
    return function(c, ...)
      c.data = {}
      local ct = c.req.head['Content-Type']
      local cl = c.req.head['Content-Length']
      local te = c.req.head['Transfer-Encoding']
      local bdr = ct and ct:match'multipart/form-data;%s?boundary%s?=%s?([^%s]+)'

      if bdr then c.bdr=bdr; core.readln(c, 2048, boundary)
      elseif te=='Chunked' then return core.readln(c, 32, chunklen) end
      cb(c, ...)
    end
  end
end
function request(c)
  local req = c.req
  local t={req.method or 'GET',' ',req.path or '/'}
  if req.qstr then ti(t,'?'); ti(t, qs_encode(req.qstr)) end
  ti(t, " HTTP/1.1\r\n")
  for k, v in pairs(req.head or {}) do
    ti(t, k); ti(t, ': '); ti(t, v); ti(t,'\r\n')
  end
  if req.jar then 
    local cookies={}
    ti(t, 'Cookie: ')
    for k, v in pairs(req.jar) do
      ti(cookies, tc{k,'=',v})
    end
    ti(t, tc(cookies,';')); ti(t, '\r\n')
  end
  if type(req.body)=='function' then
    if not req.head['Content-Length'] then
      ti(t, 'Transfer-Encoding: chunked\r\n\r\n')
      body=chunkwrap(body)
    end
    core.send_source(c, tc(t), body, '\r\n')
  elseif type(body)=='string' then
    ti(t, 'Content-Length: '); ti(t, #body); ti(t, '\r\n\r\n'); ti(t, body); ti(t, '\r\n')
    core.send(c, tc(t))
  else ti(t, '\r\n'); core.send(c, tc(t)) end
end

--- Make an asynchronous HTTP request
-- @param req
--  - host: string. Default: localhost
--  - port: number. Default: 80
--  - method: string. Default: GET
--  - path: string. Default: /
--  - qstr: table of query string variables. Optional
--  - head: table of http request headers. Optional. Host header added automatically.
--  - jar: table of cookies. Optional.
-- @param cb function that will be called with (nil, error) or (response) table.
function fetch(req, cb)

  local function head_done(c)
    --[[if c.maxlength then
      local te = c.res.head['Transfer-Encoding']
      local ct = c.res.head['Content-Type']
      local cl = c.res.head['Content-Length']
    end]]
    c.fd:close()
    c.closed=true
    return cb(c.res)
  end
  
  local function head(c, line)
    --print 'FETCH head'
    if not line then return cb(nil, 'Header byte limit exceeded')
    elseif line=='' then return head_done(c) end
    --print('FETCH head',line)
    local key, val = line:match '^([^%s:]+)%s?:%s*(.+)'
    if not key then c.closed=true; c.fd:close() return cb(nil, 'Bad header')
    elseif key=='Set-Cookie' then
      local k,v = val:match('([^;=%s]+)=([^;=%s]+)')
      if k and v then c.res.jar[k]=v end
    else c.res.head[key]=val end
    return core.readln(c, 2048, head)
  end

  local function status(c, line)
    --print 'FETCH status'
    if not line then return cb(nil, 'Status byte limit exceeded') end
    local version, status = line:match('^HTTP/(1%.%d) (%d%d%d)')
    if not version then c.closed=true c.fd:close() return cb(nil,'Bad status') end
    c.res.version=version
    c.res.status=tonumber(status)
    return core.readln(c, 2048, head)
  end

  return core.connect(req.host, req.port or 80, function(c)
    core.readln(c, 2048, status)
    c.req=req
    if not c.req.head.Host then c.req.head.Host=req.host end
    c.res={head={},jar={}}
    return request(c)
  end)
end
