local core=require'ox.core'

local tests={}

tests['on_read, on_write, server, connect, loop, stop'] = function()

  core.server(8888, function(c)
    core.on_read(c, function(c)
      local data=c.fd:read(8192)
      core.on_write(c, function(c)
        c.fd:send("ECHO: "..data)
        core.StopWrite(c)
      end)
    end)
  end)
  local n=0
  core.connect('127.0.0.1', 8888, function(c)
    core.on_write(c, function(c)
      n=n+1
      print("Write","Hello",c.fd:send("Hello"))
      if n==10 then core.stop_write(c) core.stop() end
    end)
    core.on_read(c,function(c)
      print("Read",c.fd:read(8192))
    end)
  end)
  core.loop()

end

tests[''] = function()

end

for k,fn in pairs(tests) do
  print(k)
  fn()
end
print('\t','pass.')
