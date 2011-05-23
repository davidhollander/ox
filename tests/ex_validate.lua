local core = require 'ox.core'
local http = require 'ox.http'


http.GET['^/$'] = function(c)
	http.SetHeader(c, 'Content-Type','text/html')
	http.Respond(c, 200, [[
		<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
		"http://www.w3.org/TR/html4/strict.dtd">
		<html><head><title>hello</title></head><body><div>Hello</div></body></html>
	]])
end

http.Server(8080, http)
core.Loop()
