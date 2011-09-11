local aio = {}

--- Callback once when c.buff and c.len have new data
-- the idea is to always try reading a large amount (8192) to minimize system calls
local function fill(c, cb)
  if not c.buff then c.buff = charptr(8192) end
  on_read(c, function(c)
    local m = S.read(c.fd, c.buff, 8192)
    if m==-1 then
      if ffi.errno()==S.EAGAIN then return
      else c.closed=true; return S.close(c.fd) end
    else c.len=m; stop_read(c); return cb(c) end
  end)
end

local _readln_border, _readlnB

local function _readln_border(c)
  if c.buff[0]==10 then
    c.h=c.len>1 and 1 or nil
    local k=c.k
    c.k=nil
    return c.lncb(ffi.string(c.buff2, k))
  else
    c.buff2[c.k]=13
    c.k=c.k+1
    return _readlnB(c)
  end
end

-- possible read and write offset
local function _readlnB(c)
  local h = c.h or 0
  local k = c.k or 0
  local l = c.len - h
  local m = c.max - k
  local a = c.buff + h
  local b = c.buff2 + k
  c.k, c.h = nil, nil

  if m+2 < l then --max is limiting factor
    for i=0, m+1 do
      if a[i]==13 and a[i+1]==10 then
        c.h=h+i+2
        return c.lncb(ffi.string(c.buff2, i+k))
      else b[i]=a[i] end
    end
    return c.lncb(nil, 'Exceeded max')
  else --buffer is limiting factor
    for i=0, l-2 do
      if a[i]==13 and a[i+1]==10 then
        c.h = i<l-2 and h+i+2 or nil
        return c.lncb(ffi.string(c.buff2, i+k))
      else b[i]=a[i] end
    end

    --not found in buffer
    if a[l-1]==13 then
      c.k=k+l-1
      return fill(c, _readln_border)
    else
      b[l-1]=a[l-1]
      c.k=k+l
      return fill(c, _readlnB)
    end
  end
end

--- read the next \r\n delimited chunk at most length max
-- callback with string or nil if max exceeded
function aio.readln(c, max, cb)
  c.k=nil
  c.max = max
  c.lncb = cb
  c.buff2 = charptr(max)
  if c.h then return _readlnB(c)
  else return fill(c, _readlnB) end
end

--- read exactly the next n bytes, callback with string
-- accounts for possible leftovers from readln
function aio.read(c, n, cb)
  local buff, h

  if c.h then
    h = c.h
    local l = c.len - c.h
    if l<n then --n limiting factor
      c.h=c.h+n
      return cb(ffi.string(c.buff+h, n))
    else --buffer limiting factor
      buff = charptr(n, c.buff+h)
    end
  else
    h = 0
    buff = charptr(n) 
  end

  on_read(c, function(c)
    local m = S.read(c.fd, buff+h, n-h)
    if m==-1 then
      if ffi.errno()==S.EAGAIN then return
      else c.closed=true; return S.close(c.fd) end
    else
      h = h + m
      if h>=n then
        stop_read(c)
        return cb(ffi.string(buff, h))
      end
    end
  end)
end

-- Ensure an entire message is written
function aio.write(c, buff, n, cb)
  local h = 0
  on_write(c, function()
    local m = S.write(c.fd, buff+h, n-h)
    if m==-1 then
      if ffi.errno()==S.EAGAIN then return
      else c.closed=true; return S.close(c.fd) end
    else
      h = h + m
      if h>=n then
        stop_write(c)
        return cb(true)
      end
    end
  end)
end

--- Transfer the next n bytes to destination connection table from a source table
-- Accounts for leftovers from readln operations performed on src, uses sendfile when possible
function aio.transfer(des, src, n, cb)
  local buff, h

  if c.h then
    h = c.h
    local l = c.len - c.h
    if l<n then --n limiting factor
      c.h=c.h+n
      return write(des, c.buff+h, n, cb)
    else --buffer limiting factor
      buff = charptr(n, c.buff+h)
    end
  else
    h = 0
    buff = charptr(n) 
  end

  local rdy = false
  local function combine(c)
    if rdy then
      local m = S.sendfile(a.fd, b.fd, off, count)
      if m==-1 then
        if ffi.errno()==S.EAGAIN then
          src.events = S.POLLIN; des.events = S.POLLOUT; return
        else des.closed=true; src.closed=true return cb(nil, 'Error') end
      else end
    else rdy=true;  end
  end
  on_read(src, combine)
  on_write(des, combine)
end

return aio
