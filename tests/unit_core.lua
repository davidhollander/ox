package.path=package.path..';./../?.lua'
local core=require'ox.core'

core.Serve(8888, function(c)
  core.OnRead(c, function(c)
    local data=c.fd:read(8192)
    core.OnWrite(c, function(c)
      c.fd:send("ECHO: "..data)
      core.StopWrite(c)
    end)
  end)
end)

n=0
core.Connect('127.0.0.1',8888,function(c)
  core.OnWrite(c,function(c)
    n=n+1
    print("Write","Hello",c.fd:send("Hello"))
    if n==10 then core.StopWrite(c) core.Stop() end
  end)
  core.OnRead(c,function(c)
    print("Read",c.fd:read(8192))
  end)
end)

core.Loop()
