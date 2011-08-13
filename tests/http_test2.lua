local core=require'ox.core'
local http=require'ox.http'
local port=8892
local ti, tc = table.insert, table.concat
local json = require'json'

local done = false

http.GET['^/$'] = function(c)
  local t = {'helloworld'}
  local hmsg = c.req.head.message
  local cmsg = c.req.jar.message
  if hmsg then
    c.res.head.message = hmsg
    ti(t, 'helloheader')
  end
  if cmsg then
    c.res.jar.message = cmsg
    ti(t, 'hellocookie')
  end
  c:reply(200, tc(t,', '))
end

assert(http.serve(port),'port in use')
http.fetch {
  host = 'localhost',
  port = port,
  jar = {message='hellocookie'},
  head = {message='helloheader'},
  success = function(res)
    print 'success'
    assert(res.status==200, res.status)
    assert(res.body=='helloworld, helloheader, hellocookie', 'res.body fail '..res.body)
    assert(res.jar.message=='hellocookie', 'res.jar.message fail ',res.jar.message)
    assert(res.head.message=='helloheader', 'res.head.message fail ',res.head.message)
    done=true
    core.stop()
    print 'stopping'
  end,
  error = function(res)
    print'error'
    print(json.encode(res))
  end,
}
print(core.loop)
core.loop()
assert(done, 'not done')
print('pass.')
