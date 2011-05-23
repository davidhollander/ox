local core = require 'ox.core'
local http = require 'ox.http'

core.LogFile('log.txt')

-- Create a handler
http.GET['^/error$'] = function(c)
	assert(false, "We are throwing an error in this handler")
end

http.GET['^/$'] = function(c)
	body= [[
		<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
		"http://www.w3.org/TR/html4/strict.dtd">
		<html><head><title>hello</title></head><body><div>Hello</div></body></html>
	]]
	http.SetHeader(c, 'Content-Type','text/html')
	http.SetHeader(c, 'Content-Length',#body)
	http.Respond(c, 200, body)
end

http.Server(8080, http)

-- Test
http.Client('localhost',8080,'GET','/',{},function(res)
	print('Server Status', res.status)
	print('Server headers')
	for k,v in pairs(res.headers) do print(k,v) end
	print('Server body', res.body)
	print('Reading Log File')
	local f = io.open('log.txt')
	print(f:read('*a'))
	--core.Stop()
end)

core.Loop()
