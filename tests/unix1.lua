local ox = require'ox'
local NAME = 'hello.sock'

local c, err = ox.unixserv(NAME, function(c)
  ox.readln(c, 120, function(c, line)
    print(c, line)
    assert(line=='hello world')
    ox.write(c, 'hello world\r\n', ox.close)
  end)
end)
print(c,err)

local c, err = ox.unixconn(NAME, function(c)
  ox.write(c, 'hello world\r\n', function(c)
    ox.readln(c, 120, function(c, line)
      print(c, line)
      assert(line=='hello world')
      ox.close(c)
      ox.stop()
    end)
  end)
end)
print(c, err)
ox.start()
print 'pass'
