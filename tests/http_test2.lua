local core=require'ox.core'
local http=require'ox.http'
local D=require'ox.data'
local port=8892
local ti, tc = table.insert, table.concat

local done = false

http.hosts.localhost = {GET={}}
local site = http.hosts.localhost

site.GET['^/$'] = function(c)
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

local req = {
	host='localhost',
	port=port,
	jar = {message='hellocookie'},
	head = {message='helloheader'}
}
assert(http.serve(port),'port in use')
print('Serving on', port)
http.fetch(req, function(res, err)
	print('fetch CB', res, err)
	assert(res and res.status==200, res.status)
	print(D.serialize(res))
	--assert(res.body=='helloworld, helloheader, hellocookie', 'res.body fail '..res.body)
	assert(res.jar.message=='hellocookie', 'res.jar.message fail ',res.jar.message)
	assert(res.head.message=='helloheader', 'res.head.message fail ',res.head.message)
	done=true
	core.stop()
	print 'stopping'
end)

core.loop()
assert(done, 'not done')
print('pass.')
