local core=require'ox.core'
local http=require'ox.http'
local port=8889
local ti, tc = table.insert, table.concat

local done = false

http.GET['^/$'] = function(c)
  local out = {'hello world'}
  local cmsg = http.cookie(c, 'message')
  local hmsg = http.header(c, 'message')
  if cmsg then
    ti(out, cmsg)
    http.cookie(c, 'message', cmsg)
  end
  if hmsg then
    ti(out, cmsg)
    http.header(c, 'message', hmsg)
  end
  http.reply(c, 200, tc(out,', '))
end

http.fetch {
  host = 'localhost',
  port = port,
  jar = {message='hello cookie'},
  head = {message='hello header'},
  done = function(res)
    assert(res)
    assert(res.status==200)
    assert(res.body=='hello world, hello cookie, hello header')
    assert(res.jar.message=='hello cookie')
    assert(res.head.message=='hello header')
    done=true
    core.stop()
  end,
}

http.serve(port, http)
core.loop()
assert(done)
print('pass.')
