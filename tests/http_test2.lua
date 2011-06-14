local core=require'ox.core'
local http=require'ox.http'
local port=8889
local ti, tc = table.insert, table.concat
local json = require'json'

local done = false

http.GET['^/$'] = function(c)
  print('handling page', json.encode(c))
  local out = {'hello world'}
  local cmsg = http.cookie(c, 'message')
  local hmsg = http.header(c, 'message')
  if cmsg then
    ti(out, cmsg)
    http.cookie(c, 'message', cmsg)
  end
  if hmsg then
    ti(out, hmsg)
    http.header(c, 'message', hmsg)
  end
  print(json.encode(c))
  http.reply(c, 200, tc(out,', '))
end

http.fetch {
  host = 'localhost',
  port = port,
  jar = {message='hellocookie'},
  head = {message='helloheader'},
  success = function(res)
    print(json.encode(res))
    print('fetch success')
    assert(res.status==200, res.status)
    assert(res.body=='hello world, hellocookie, helloheader', 'res.body fail '..res.body)
    assert(res.jar.message=='hellocookie', 'res.jar.message fail ',res.jar.message)
    assert(res.head.message=='helloheader', 'res.head.message fail ',res.head.message)
    done=true
    core.stop()
  end,
}

http.serve(port, http)
core.loop()
assert(done)
print('pass.')
