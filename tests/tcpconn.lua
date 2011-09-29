local ox = require 'ox'
local PORT = 8094 or ...
print(PORT)

ox.split(1,function()
  print(ox.tcpserv(PORT, function(c)
    return ox.readln(c, 2048, function(c, line)
      print('server readln', line)
      return ox.write(c, line..'\n', function(c)
        ox.close(c)
      end)
    end)
  end))
  ox.at(ox.time+2,ox.stop)
  ox.start()
end)

local function addrinfo()
  print(ox.tcpconn('localhost',PORT,function(c)
    ox.write(c, 'Hello\n', function(c)
      ox.readln(c, 2048, function(c, line)
        assert(line=='Hello')
        ox.close(c)
      end)
    end)
  end))
end

local function ip6()
  print(ox.tcpconn('127.0.0.1',PORT,function(c)
    ox.write(c, 'Hello\n', function(c)
      ox.readln(c, 2048, function(c, line)
        assert(line=='Hello')
        ox.close(c)
        return addrinfo()
      end)
    end)
  end))
end

local function ip4()
  print(ox.tcpconn('127.0.0.1',PORT,function(c)
    ox.write(c, 'Hello\n', function(c)
      ox.readln(c, 2048, function(c, line)
        assert(line=='Hello')
        ox.close(c)
        return ip6()
      end)
    end)
  end))
end

ox.at(ox.time+1, ip4)
ox.at(ox.time+2,ox.stop)
ox.start()

print 'pass'
