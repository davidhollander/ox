-- FFI
--
local ffi = require'ffi'
ffi.cdef [[
typedef unsigned long ino_t;
typedef long off_t;
typedef struct DIR DIR;
struct dirent {
    ino_t          d_ino;       /* inode number */
    off_t          d_off;       /* offset to the next dirent */
    unsigned short d_reclen;    /* length of this record */
    unsigned char  d_type;      /* type of file */
    char           d_name[256]; /* filename */
};

DIR *opendir(const char *name);
int closedir(DIR *dir);
struct dirent *readdir(DIR *dir);
]]
local C = ffi.C

-- fs
--
local fs = {}
function fs.dir(path)
  local dir = ffi.gc(C.opendir(path or '.'), C.closedir)
  return dir~=nil and function()
    local entry = C.readdir(dir)
    if entry~=nil then return ffi.string(entry.d_name) end
  end or function() end
end

--- Glob alternative. Uses question mark as wildcard.
function fs.gdir(str)
  local dir, p = str:match '(.-)([^/]+)$'
  p=p:gsub('[%(%)%%%.%[%]%*%+%-]',function(c) return '%'..c end)
  local f = fs.dir(dir and dir~='' and dir or '.')
  local ptrn = '^'..p:gsub('?','.+')..'$'
  return function()
    local x
    repeat x = f()
    until x==nil or x:match(ptrn)
    return x and dir..x or nil
  end
end

return fs
