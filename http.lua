-- ox.http
-- Copyright (c) 2011 David Hollander
-- Released under the simplified BSD license, see LICENSE.txt

-- an http server and utility functions

local core=require 'ox.core'
local lhp=require'http.parser'
local json=require'json'
local tc = table.concat
local ti = table.insert
local hosts={}
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

GET,PUT,POST,DELETE={},{},{},{}
local handlers={GET=GET,PUT=PUT,POST=POST,DELETE=DELETE}

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

---Send an HTTP response and close connection when done.
--@param c table. The connection this applies to.
--@param status number. The HTTP status code.
--@param body nil, string, or function. The response body. If a function, the response ends when [body] returns nil
function reply(c, status, body)
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

function server_error(c, err)
  core.log('500',err)
  return core.finish(c, tc{status_line[500],'\r\n',err,'\r\n'})
end

-- reply_json(c, status, body)
-- shortcut for sending json
function reply_json(c, status, body)
  c.res.head['Content-Type']='application/json'
  return reply(c, status, json.encode(body))
end

---converts a date into a string appropriate for a HTTP header
-- ex: Wed, 09 Jun 2021 10:18:14 GMT
function datetime(utcseconds)
  return os.date('!%a, %d %b %Y %H:%M:%S %Z', utcseconds)
end

local web_methods={reply=reply}
local web_mt={
  __index=function(t,k) return web_methods[k] or rawget(t,k) end
}

local decoders={
  ['application/x-www-form-urlencoded']=qs_decode,
  ['application/json']=json.decode,
}

function CRLF_lines(c, bytes)
  local init=1
  if c.border then
    if bytes:sub(1,1)=='\n' then
      c:state(tc(c.buffer))
      if c.closed then return end
      c.buffer={}
      init=2
    else ti(c.buffer, '\n') end
    c.border=nil
  end
  while true do
    local h = bytes:find('\r', init)
    if h then 
      if h==#bytes then
        c.border=true
        ti(c.buffer, bytes:sub(init,-2))
        break
      elseif #c.buffer==0 then
        c:state(bytes:sub(init, h-1))
        if c.closed then return end
      else
        ti(c.buffer, bytes:sub(init, h-1))
        c:state(tc(c.buffer))
        if c.closed then return end
        c.buffer={}
      end
      init=h+2
    else ti(c.buffer, bytes:sub(init, #bytes)); break end
  end
end

function parser()
  print 'parser'
  local hosts={}
  
  local function head(c, line)
    print('head',line)
    if line=='' then
      local h = c.req.head.Host
      local host = hosts[h and h:match'[%w%.]+' or false] or hosts[true]
      if not host then
        print('host not found',h,host)
        return reply(c, 404)
      else print 'host found'; return host(c) end
    end
    local key, value = line:match('^([%w_%-])+ ?: ?([%w_%-]+)$')
    print('kv',key,value)
    if not key then return reply(c, 400) end
    c.req.head[key]=value
  end
  
  local _methods={GET=true, POST=true, DELETE=true, PUT=true}
  local function status(c, line)
    print('status', line)
    local method, path = line:match('(%w+) ([^%s]+) HTTP/1%.%d$')
    if not _methods[method] then c.fd:close(); c.closed=true return
    else c.req.method=method; c.req.path=path; c.state=head; c.req.head={} end
  end

  local function read(c)
    print 'read'
    local bytes, err = c.fd:read(8192)
    if err then c.fd:closed(); c.closed=true; print 'closed' return
    elseif bytes==false then return
    else CRLF_lines(c, bytes) end
  end

  return setmetatable(hosts,{
    __call = function(_, c)
      print 'parser'
      c.req = {}
      c.res={head={},jar={}}
      c.buffer={}
      c.state = status
      core.on_read(c, read)
    end
  })
end

function host(name)
  local t={GET={},POST={}}
  hosts[name]=t
  return setmetatable(t or {GET={},POST={}},{
    __call = function(methods, c)
      print 'host'
      local m = methods[c.req.method]
      if not m then return reply(c, 405) end
      local h, capture
      for k,v in pairs(m) do
        capture = {c.req.path:match(k)}
        if #capture>1 then h=v break end
      end
      if not h then return reply(c, 404)
      else return h(c, unpack(capture)) end
    end
  })
end

--- Make an asynchronous HTTP request
-- @param req
--  - host: string. Default: localhost
--  - port: number. Default: 80
--  - method: string. Default: GET
--  - path: string. Default: /
--  - qstr: table of query string variables. Optional
--  - head: table of http request headers. Optional. Host header included automatically.
--  - jar: table of cookies. Optional.
--  - [number]: function to handle a specific HTTP response status code. Optional.
--  - success: function to handle all 20x responses. Optional.
--  - redirect: function to handle all 30x responses. Optional.
--  - error: function to handle all 40x and 50x responses. Optional.
function fetch(req)
  return core.connect(req.host, req.port or 80, function(c)
    
    req.head = req.head or {}
    if not req.head.Host then req.head.Host=req.host end
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
    -- response parser
    local res={head={},body={},jar={}}
    local done=false
    local parser=lhp.response{
      on_header=function(key,val)
        if key=='Set-Cookie' then
          local k,v = val:match('([^;=%s]+)=([^;=%s]+)')
          if k and v then res.jar[k]=v end
        else res.head[key]=val end
      end,
      on_body=function(chunk) table.insert(res.body,chunk) end,
      on_message_complete=function() done=true end,
      on_headers_complete=function() end,
    }
    core.on_read(c, function(c)
      local data=c.fd:recv(8192)
      if data==false then return 
      elseif data==nil or data=='' or parser:execute(data)==0 or done then
        res.status=parser:status_code();
        res.body=table.concat(res.body)
        c.fd:close()
        if req[res.status] then req[res.status](res)
        elseif res.status>=200 and res.status<300 and req.success then
          req.success(res)
        elseif res.status>=300 and res.status<400 and req.redirect then
          req.redirect(res)
        elseif res.status>=400 and req.error then
          req.error(res)
        end
        return 'close'
      end
    end)
  end)
end
