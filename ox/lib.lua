--lib
--Sleep, compress, uncompress based off of FFI tutorial by Mike Pall
--http://luajit.org/ext_ffi_tutorial.html
local ffi = require 'ffi'
local cdef = ffi.cdef


local lib = {}
cdef 'void Sleep(int ms)'
cdef 'int poll(struct pollfd *fds, unsigned long nfds, int timeout)'
if ffi.os == "Windows" then
  function lib.sleep(s)
    ffi.C.Sleep(s*1000)
  end
else
  function lib.sleep(s)
    ffi.C.poll(nil, 0, s*1000)
  end
end


cdef [[
unsigned long compressBound(unsigned long sourceLen);
int compress2(uint8_t *dest, unsigned long *destLen,
        const uint8_t *source, unsigned long sourceLen, int level);
int uncompress(uint8_t *dest, unsigned long *destLen,
         const uint8_t *source, unsigned long sourceLen);
]]
local zlib = ffi.load(ffi.os == "Windows" and "zlib1" or "z")
local arr_uint8 = ffi.typeof 'uint8_t[?]'
local ptr_ulong = ffi.typeof 'unsigned long[1]'

function lib.compress(txt)
  local n = zlib.compressBound(#txt)
  local buf = arr_uint8(n)
  local buflen = ptr_ulong(n)
  local res = zlib.compress2(buf, buflen, txt, #txt, 9)
  assert(res == 0)
  return ffi.string(buf, buflen[0])
end

function lib.uncompress(comp, n)
  local buf = ffi.new("uint8_t[?]", n)
  local buflen = ffi.new("unsigned long[1]", n)
  local res = zlib.uncompress(buf, buflen, comp, #comp)
  assert(res == 0)
  return ffi.string(buf, buflen[0])
end

return lib
