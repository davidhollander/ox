-- ox.http
-- Copyright 2011 by David Hollander
-- MIT License

local ox = require 'ox'
local lib = require 'ox.lib'
local tbl = require 'ox.tbl'
local mime_types = require 'ox.mime'
local glt_put, glt_nest, glt_get = lib.globtrie_put, lib.globtrie_nest, lib.globtrie_get
local ti, tc = table.insert, table.concat
local http = {
  head_line_max = 2048,
  head_max = 8192,
}
local hosts = {}

-- FFI
--
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

function http.writechunk(c) end
function http.writechunk_gzip(c) end

function http.stream(c)
  local chunk = c.body_source()
  if not chunk then return ox.write(c, '\r\n', ox.close)
  else return ox.write(c, chunk, http.stream) end
end

function http.close(c)
  return ox.write(c, '\r\n', ox.close)
end

function http.writehead(c, cb)
  local s = RES_STATUS[status]
  if not s then assert(s, 'Bad status: '..status) end
  local t = {s}
  for k,v in pairs(c.res.head or {}) do
    ti(t, k); ti(t, ':  '); ti(t, v); ti(t, '\r\n')
  end
  for k,v in pairs(c.res.jar or {}) do
    ti(t, 'Set-Cookie: ') ti(t, k); ti(t, '='); ti(t, v); ti(t, '\r\n')
  end
  return ox.write(c, tc(t), cb)
end

function http.nohead(c, status, body)
  return ox.write(c, tc{RES_STATUS[status],'\r\n',body or '','\r\n'}, ox.close)
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
  if type(body)=='function' then
    c.body_source=body
    if not c.res.head['Content-Length'] then
      ti(t, 'Transfer-Encoding: chunked\r\n')
    end
    ti(t, '\r\n')
    return ox.write(c, tc(t), ox.stream)
  elseif type(body)=='string' then
    ti(t, 'Content-Length: ') ti(t, #body) ti(t, '\r\n\r\n') ti(t, body) ti(t, '\r\n')
    return ox.write(c, tc(t), ox.close)
  else return ox.write(c, tc(t), ox.close) end
end

function http.transfer(c, status, src)
end

function http.stream(c, status, src)
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
  local n = tonumber(len, 16)
  if n == 0 then
    c.body = tc(c.body)
    return c:on_body(true)
  elseif c.body_len+n>c.body_max then return c:on_body(false)
  else
    c.body_len = c.body_len + n
    return ox.read(c, n, readbody_chunk)
  end
end

local function readbody_part(c, line)
  if line==c.bdr then return ox.readln(c, 1024, readbody_parthead)
  else
    ti(c.part, line)
    return ox.readln(c, c.body_max, readbody_part)
  end
end

local function readbody_parthead(c, line)
  if line=='' then ox.readln(c, c.body_max, readbody_part) end
  local key, val = line:match('^([%w_%-])+ ?: ?([%w_%-]+)$')
  if key then c.part[key] = val end
  return ox.readln(c, 1024, readbody_parthead)
end

local function readbody_boundary(c, line)
  if line==c.bdr then
    c.part = {}
    ti(c.data, c.part)
    return ox.readln(c, 1024, readbody_parthead)
  end
end

function http.readbody(c, max, maxparts, cb)
  c.body_max = max
  local head = (c.req or c.res).head
  local te = head['Transfer-Encoding']
  local cl = head['Content-Length']
  local ct = head['Content-Type']
  local boundary = ct and ct:match 'multipart/form-data;%s?boundary%s?=%s?([^%s]+)'
  if boundary then
    c.bdr = boundary
    c.body_maxparts = maxparts
    return ox.readln(c, 2048, readbody_boundary)
  elseif te and te:match 'chunked' then
    return ox.readln(c, 2, readbody_chunklen)
  elseif cl and cl<max then
    return ox.read(c, max, readbody_all)
  end
end

function http.readbody_mp(c, max, maxparts, cb)
  
end

function http.transferbody(c, max, maxfiles, cb)
end

-- REQUEST
--

local function readreq_head(c, line)
  if not line then return reply(c, 413)
  elseif line=='' then return c:on_request() end

  local key, val = line:match '^([^%s:]+)%s?:%s*(.+)'
  if not key then return reply(c, 400)
  elseif key=='Cookie' then
    for k,v in val:gmatch('([^;=%s]+)=([^;=%s]+)') do
      c.req.jar[k]=v
    end
  else c.req.head[key]=val end
  return ox.readln(c, 2048, readreq_head)
end
 
local function readreq_status(c, line)
  if not line then return reply(c, 414) end
  local method, path = line:match '(%u+) ([^%s]+) HTTP/1%.%d$'
  if not method or not METHODS[method] then return ox.close(c)
  else c.req.method=method; c.req.path=path; return ox.readln(c, 2048, readreq_head) end
end


function http.readreq(c, cb)
  c.on_request = cb
  c.req={head={},jar={}}
  return ox.readln(c, 2048, readreq_status)
end

function http.folder(dir)
  local dir=dir:match('^(.+)/?$')
  return function(c, path)
    local rh=c.res.head
    local f = not path:match('%.%.') and ox.open(dir..'/'..path)
    if not f then return http.nohead(c, 404, 'Invalid path') end
    local ext = path:match('%.(%w+)$')
    local mime = mime_types[ext] or 'application/octet-stream'
    rh['Content-Type'] = mime
    local stats = f:stat()
    rh['Last-Modified']=http.datetime(stats.mtime)
    rh['Content-Length']= stats.size
    c:reply(200, source_file(f))
  end
end




-- RESPONSE
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
  return core.readln(c, 2048, readres_head)
end

function http.readres(c, cn)
  c.on_response = cn
  c.res = {head={},jar={}}
  return ox.readln(c, 2048, readres_status)
end



return http
