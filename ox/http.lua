-- ox.http
-- Copyright 2011 by David Hollander
-- MIT License

local ox = require 'ox'
local lib = require 'ox.lib'
local tbl = require 'ox.tbl'
--local mime_types = require 'ox.mime'
local glt_put, glt_nest, glt_get = lib.globtrie_put, lib.globtrie_nest, lib.globtrie_get
local ti, tc = table.insert, table.concat
local http = {
  head_line_max = 2048,
  head_max = 8192,
}
local hosts = {}

-- FFI
--
local ffi = require 'ffi'
local C, cdef = ffi.C, ffi.cdef
local zlib = ffi.load(ffi.os == "Windows" and "zlib1" or "z")
cdef[[int compress2(uint8_t *dest, unsigned long *destLen,
        const uint8_t *source, unsigned long sourceLen, int level);
int uncompress(uint8_t *dest, unsigned long *destLen,
         const uint8_t *source, unsigned long sourceLen);

]]

-- CONSTANTS
--
local METHODS = {
  DELETE = true,
  GET = true,
  HEAD = true,
  POST = true,
  PUT = true
}

local RES_STATUS = {
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

-- RENDERING
--

function http.url_decode(str)
  if not str then return nil end
  str = string.gsub (str, "+", " ")
  str = string.gsub (str, "%%(%x%x)", function(h) return string.char(tonumber(h,16)) end)
  str = string.gsub (str, "\r\n", "\n")
  return str
end

--make sure to leave '.','-','~','_' as is
--- Encode a url string
function http.url_encode(str)
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
function http.qs_decode(qstr)
  local t={}
  for k,v in string.gmatch(qstr, "([^&=]+)=([^&=]*)&?") do
    if #v>0 then t[http.url_decode(k)] = http.url_decode(v)
    else t[http.url_decode(k)] = true end
  end
  return t
end

--- Encode query string or form body
-- @param table
-- @return string
function http.qs_encode(t)
  local out={}
  for k,v in pairs(t) do
    if v~=true then
      ti(out, tc{http.url_encode(k),'=',http.url_encode(v)})
    else ti(t, k) end
  end
  return tc(out, '&')
end

local httpmt = {
  write = function(c, ...)
    for _,v in ipairs(...) do ti(c.out, v) end
  end,
  writef = function(c, ptrn, ...)
    ti(c.out, string.format(ptrn, ...))
  end,
  flush = function(c, cb)
    return ox.write(c, tc(c.out), cb)
  end
}

function http.close(c)
  return ox.write(c, '\r\n', ox.close)
end
function http.nohead(c, status, body)
  return ox.write(c, tc{RES_STATUS[status],'\r\n',body or '','\r\n'}, ox.close)
end

function http.writeres_head(c, cb)
  local s = RES_STATUS[status]
  if not s then assert(s, 'Bad status: '..status) end
  local t = {s}
  for k,v in pairs(c.res.head or {}) do
    ti(t, k); ti(t, ':  '); ti(t, v); ti(t, '\r\n')
  end
  for k,v in pairs(c.res.jar or {}) do
    ti(t, 'Set-Cookie: ') ti(t, k); ti(t, '='); ti(t, v); ti(t, '\r\n')
  end
  ti(t, '\r\n')
  return ox.write(c, tc(t), cb)
end

function http.reply(c, status, body)
  local s = RES_STATUS[status]
  if not s then assert(s, 'Bad status: '..status) end
  local t = {s}
  for k,v in pairs(c.res.head or {}) do
    ti(t, k); ti(t, ':  '); ti(t, v); ti(t, '\r\n')
  end
  for k,v in pairs(c.res.jar or {}) do
    ti(t, 'Set-Cookie: ') ti(t, k); ti(t, '='); ti(t, v); ti(t, '\r\n')
  end
  local cl = c.req.head['Content-Length']
  if body and type(body)=='string' then
    ti(t, 'Content-Length: ') ti(t, #body) ti(t, '\r\n\r\n') ti(t, body) ti(t, '\r\n')
    return ox.write(c, tc(t), ox.close)
  end
  return ox.write(c, tc(t), ox.close)
end

-- ROUTES
--
function http.route(host)
  return function(method)
    return function(path)
      return function(cb)
        local methods = glt_nest(hosts, host)
        local paths = glt_nest(methods, method)
        glt_put(paths, path, cb)
      end
    end
  end
end

function http.routereq(c)
  local methods, cap1 = glt_get(hosts, c.req.head.Host or '')
  if not methods then return http.nohead(c, 404, 'Host not found') end

  local paths, cap2 = glt_get(methods, c.req.method)
  if not paths then return http.nohead(c, 405, 'Method not supported') end

  local cb, cap3 = glt_get(paths, c.req.path)
  if not cb then return http.nohead(c, 404, 'Not Found') end

  c.res = {jar={}, head={}}
  local ok, err = pcall(cb, c, tbl.unpackn(cap1, cap2, cap3))
  if err then return http.nohead(c, 500, err) end
end

function http.accept(c) return http.readreq(c, http.routereq) end

-- BODY
--
local readbody_chunklen

local function readbody_chunk(c, chunk)
  if not c.body then c.body = {chunk}
  else ti(c.body, chunk) end
  return ox.read(c, 2, readbody_chunklen)
end
local function readbody_chunklen(c, len)
  if len == '' then
    c.body = tc(c.body)
    return c:on_body(true)
  end
  local n = tonumber(len, 16)
  if c.body_len+n>c.body_max then return c.on_body(false)
  else
    c.body_len = c.body_len + n
    return ox.read(c, n, readbody_chunk)
  end
end


-- MULTIPART

-- meh more garbage collection
-- request keys: method, path, length, multipart, 


-- reading
local mpart_bdr = setmetatable({},{__mode='k'})
local mpart_cb = setmetatable({},{__mode='k'})

function http.readpart(c, max, cb)
  local t = (c.req or c.res)
  local ct = t and t.head['Content-Type']
  local bdr = ct and ct:match 'multipart/form-data;%s?boundary%s?=%s?([^%s]+)'
  if not bdr then return cb(c) end
  c.on_part = cb
  c.max = max
  c.boundary = bdr
  return ox.readln(c, 2048, readbody_boundary)
end

local function readpart_boundary(c, line)
  if line==c.boundary then
    c.part = {}
    return ox.readln(c, 1024, readpart_head)
  else return c:on_part() end
end

local function readpart_head(c, line)
  if line=='' then ox.readln(c, c.body_max, readpart) end
  local key, val = line:match('^([%w_%-])+ ?: ?([%w_%-]+)$')
  if key then c.part[key] = val end
  return ox.readln(c, 1024, readbody_parthead)
end

local function readpart(c, line)
  if line==c.boundary then return ox.readln(c, 1024, readbody_parthead)
  else
    ti(c.part, line)
    return ox.readln(c, c.body_max, readbody_part)
  end
end

-- writing

function http.writepart(c, head, body, cb)
  if not c.boundary then c.boundary = ('----%x'):format(math.random(1e6))
  end
end




--[[HTTP BODY
function http.readbody(c, max, cb)
  c.body_max = max
  c.on_body = cb
  local head = c.res and c.res.status and c.res.head or c.req.head
  local te = head['Transfer-Encoding']
  local cl = head['Content-Length']
  local ct = head['Content-Type']
  elseif te and te:match 'chunked' then
    return ox.readln(c, 4, readbody_chunklen)
  elseif cl and cl<max then
    return ox.read(c, max, readbody_all)
  end
end]]



-- SERVER
--

local function readreq_head(c, line)
  if not line then return http.nohead(c, 413)
  elseif line=='' then return c:on_request() end

  local key, val = line:match '^([^%s:]+)%s?:%s*(.+)'
  if not key then return http.nohead(c, 400)
  elseif key=='Cookie' then
    for k,v in val:gmatch('([^;=%s]+)=([^;=%s]+)') do
      c.req.jar[k]=v
    end
  else c.req.head[key]=val end
  return ox.readln(c, 2048, readreq_head)
end
 
local function readreq_status(c, line)
  if not line then return http.nohead(c, 414) end
  local method, path = line:match '(%u+) ([^%s]+) HTTP/1%.%d$'
  if not method or not METHODS[method] then return ox.close(c)
  else c.req.method=method; c.req.path=path; return ox.readln(c, 2048, readreq_head) end
end

--- Set c.req
function http.readreq(c, cb)
  c.on_request = cb
  c.req={head={},jar={}}
  return ox.readln(c, 2048, readreq_status)
end

-- CLIENT
--
local function readres_head(c, line)
  if not line then return c:on_response(false)
  elseif line=='' then return c:on_response() end

  local key, val = line:match '^([^%s:]+)%s?:%s*(.+)'
  if not key then ox.close(c) return c:on_response(false)
  elseif key=='Set-Cookie' then
    local k,v = val:match('([^;=%s]+)=([^;=%s]+)')
    if k and v then c.res.jar[k]=v end
  else c.res.head[key]=val end
  return ox.readln(c, 2048, readres_head)
end

local function readres_status(c, line)
  if not line then return c:on_response(false) end
  local version, status = line:match('^HTTP/(1%.%d) (%d%d%d)')
  if not version then ox.close(c) return c:on_response(false) end
  c.res.version=version
  c.res.status=tonumber(status)
  return ox.readln(c, 2048, readres_head)
end

function http.readres(c, cn)
  c.on_response = cn
  c.res = {head={},jar={}}
  return ox.readln(c, 2048, readres_status)
end

--req.multipart --> generate boundary
--req.length --> known length, if not set will used chunked encoding

function http.writereq(c, cb)
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
  --[[if type(req.body)=='function' then
    if not req.head['Content-Length'] then
      ti(t, 'Transfer-Encoding: chunked\r\n\r\n')
      body=chunkwrap(body)
    end
    return ox.write(c, tc(t), body, '\r\n')]]
  if type(req.body)=='string' then
    ti(t, 'Content-Length: '); ti(t, #body); ti(t, '\r\n\r\n'); ti(t, body); ti(t, '\r\n')
    return ox.write(c, tc(t), cb)
  else
    ti(t, '\r\n\r\n')
    return ox.write(c, tc(t), cb)
  end
end

function http.fetch(req, cb)
  return ox.tcpconn(req.host, req.port or 80, function(c)
    c.req = req
    c.res = {jar={},head={}}
    http.writereq(c, ox.pass)
    return http.readres(c, cb)
  end)
end

return http
