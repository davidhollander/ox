local core=require'ox.core'

local tests={}

tests['on_read, on_write, server, connect, loop, stop'] = function()
  core.serve(8888, function(c)
    core.on_read(c, function(c)
      local data=c.fd:read(8192)
      core.on_write(c, function(c)
        c.fd:send(data)
        core.stop_write(c)
      end)
    end)
  end)
  local n=0
  local text=''
  core.connect('127.0.0.1', 8888, function(c)
    core.on_write(c, function(c)
      n=n+1
      c.fd:send('Hello')
      if n==10 then core.stop_write(c) end
    end)
    core.on_read(c,function(c)
      text = text..c.fd:read(8192)
      if text==string.rep('Hello',10) then
        assert(n==10)
        core.stop()
      end
    end)
  end)
  core.loop()
  assert(n==10)
end

tests['log'] = function()
  nixio.fs.remove('log.txt')
  core.log('log')
  core.log_file('log.txt')
  core.log('log1;')
  core.log('log2;')
  local f = io.open('log.txt','r')
  assert(f:read('*a')=="log1;log2;")
  f:close()
  nixio.fs.remove('log.txt')
end

for k,fn in pairs(tests) do
  print(k)
  fn()
end
print('pass.')
