-- ox.ffi
-- Copyright (c) 2011 David Hollander
-- Released under the simplified BSD license, see LICENSE.txt

-- The LuaJIT ffi also provides a path for future increases in 
-- cpu and memory efficiency while decreasing rather than increasing the number
-- of C dependencies.

local ffi=require'ffi'
local test={}

-- Poll
ffi.cdef[[
int poll(struct pollfd *fds, unsigned long nfds, int timeout);
struct pollfd {
  int fd;
  short events;
  short revents;
}
]]

function evpoll(t)
  local pollfds = ffi.new("pollfd[?]",#t)
  for i=1,#t do
    pollfds[i].fd=t[i].fd
    pollfds[i].events=t[i].events
  end
  ffi.C.poll(pollfds,#t,1000)
end

function test.poll()
  local t1=os.time()
  ffi.C.poll(nil, 0, 1100)
  assert(os.time()-t1>=1)
end

-- Socket
ffi.cdef[[
int socket(int domain, int type, int protocol);
]]

function sockbind()
end


function test()
  for k,f in pairs(test) do
    print("Test",k)
    f()
  end
end
