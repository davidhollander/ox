local ox=require'ox'
local http=require'ox.http'
local tbl = require 'ox.tbl'
local PORT = ... or 8892
local ti, tc = table.insert, table.concat

local done = false

http.route '*' '*' '/' (function(c)
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
  return http.reply(c, 200, tc(t,', '))
end)

local req = {
	host='localhost',
	port=PORT,
	jar = {message='hellocookie'},
	head = {message='helloheader'}
}
assert(ox.tcpserv(PORT, http.accept))
print(PORT)

http.fetch(req, function(c, err)
	print('fetch CB', res, err)
  print(tbl.dump(res))
  local res = c.res
	assert(res and res.status==200, res.status)
	--assert(res.body=='helloworld, helloheader, hellocookie', 'res.body fail '..res.body)
	assert(res.jar.message=='hellocookie', 'res.jar.message fail ',res.jar.message)
	assert(res.head.message=='helloheader', 'res.head.message fail ',res.head.message)
	done=true
	ox.stop()
	print 'stopping'
end)

ox.start()
assert(done, 'not done')
print 'pass.'
