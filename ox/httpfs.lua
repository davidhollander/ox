
-- FILE SERVING
--
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
    http.writehead(c, function(c)
      return ox.transfer(c, f, stats.size, http.close)
    end)
  end
end

--[[
function http.transferbody(c, max, maxfiles, cb)
  c.body_max = max
  c.on_body = cb
  local head = c.res and c.res.status and c.res.head or c.req.head
  local te = head['Transfer-Encoding']
  local cl = head['Content-Length']
  local ct = head['Content-Type']
  local boundary = ct and ct:match 'multipart/form-data;%s?boundary%s?=%s?([^%s]+)'
  if boundary then
    c.bdr = boundary
    c.body_maxparts = maxparts
    return ox.readln(c, 2048, readbody_boundary)
  elseif te and te:match 'chunked' then
    return ox.readln(c, 4, readbody_chunklen)
  elseif cl and cl<max then
    return ox.read(c, max, readbody_all)
  end
end]]

local function transfer_chunk(des, src)
end
local function transfer_chunklen(c, len)
  if len == '' then return c:on_body() end
  local n = tonumber(len, 16)
  if c.body_len + n>c.body_max then return c.on_body(false)
  else
    c.body_len = c.body_len + n
    return ox.transfer(f, c, n, transfer_chunk)
  end
end


