local core=require'ox.core'
local http=require'ox.http'
local nixio=require'nixio','nixio.util'
local host='localhost'
local port=8889
local timeout=2
local req_root = 'GET / HTTP/1.1\r\n\r\n'
local req_quit = 'GET /shutdown HTTP/1.1\r\n\r\n'


tests={}
function addtest(t)
  table.insert(tests, t)
end

addtest {
  name = "Reply",
  note = "Send an HTTP request and read response",
  test = function()
    local sock,err,m = nixio.connect(host, port)
    sock:write(req_root)
    sock:read(1024)
    sock:close()
    return true
  end
}
addtest {
  name = "Disconnect",
  note = "Open and immediately close a connection",
  test = function()
    local sock,err,m = nixio.connect(host, port)
    sock:close()
    return true
  end
}
addtest {
  name = "Disconnect2",
  note = "Close connection while sending request",
  test = function()
    local mysock,err,m = nixio.connect(host, port)
    mysock:write('GET ')
    mysock:close()
    return true
  end
}
addtest {
  name = "Send Garbage",
  note = "Spam server, hopefully getting immediately disconnected",
  test = function()
    local mysock, err, m = nixio.connect(host, port)
    local c = os.time()
    while true do
      local n, e, m = mysock:write(tostring(math.random(10e10)))
      if not n then 
        break
      end
    end
    assert((os.time()-c)<timeout)
    return true
  end
}
addtest {
  name = "timeout",
  note = 'leave connection open without sending anything, hopefully getting expired',
  test = function()
    local sock, err, m = nixio.connect(host, port)
    local n = nixio.poll({{fd=sock, events=nixio.poll_flags('in'),revents=0}},(timeout+2)*1000)
    assert(n==1)
    return true
  end
}
addtest {
  name = "timeout2",
  note = "leave connection open after sending part of request, hopefully getting expired",
  test = function()
    local sock, err, m = nixio.connect(host, port)
    sock:send('GET')
    local n = nixio.poll({{fd=sock, events=nixio.poll_flags('in'),revents=0}},(timeout+2)*1000)
    assert(n==1)
    return true
  end
}
addtest {
  name = "nonblocking",
  note = "open a second connection before writing first to ensure nonblocking",
  test = function()
    local sock=nixio.connect(host, port)
    local sock2=nixio.connect(host, port)
    sock2:write(req_root)
    assert(sock2:read(12)=='HTTP/1.1 200')
    sock2:close()
    sock:write(req_root)
    assert(sock:read(12)=='HTTP/1.1 200')
    sock:close()
    return true
  end
}
addtest {
  name = "url_encode and url_decode",
  note = "",
  test = function()
    local str="hello x me = ss?q=23&23age Message /!@#& @("
    assert(str==http.url_decode(http.url_encode(str)))
    return true
  end
}
addtest {
  name = "qs_encode and qs_decode",
  note = "",
  test = function()
    local str="hello x me = ss?q=23&23age Message /!@#& @("
    local t = http.qs_decode('message='..http.url_encode(str)..'&bool=')
    assert(t.message==str and t.bool==true)
    return true
  end
}

function quit()
  local sock,err,m = nixio.connect(host, port)
  print('QUIT',sock, err,m)
  sock:send(req_quit)
  sock:close()
  return true
end

http.GET['^/$'] = function(c)
  http.reply(c, 200, "Hello")
end
http.GET['^/shutdown$'] = function(c)
  os.exit()
end

local n=0
local function dotest()
  core.trigger(function()
    n=n+1
    if n>#tests then return core.stop() end
    local t=tests[n]
    print(n, t.name, t.note)
    core.call_fork(t.test, dotest)
  end,0)
end
dotest()

http.serve(port, http)
core.loop(timeout)
print('pass.')
