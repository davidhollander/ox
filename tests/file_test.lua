local ti, tc = table.insert, table.concat
local core=require'ox.core'
local http=require'ox.http'
local file=require'ox.file'

files={}
files['script.js']="alert('Hello');"
files['page.html']="<html><body>Hello</body></html>"
local nfiles=0; for k,v in pairs(files) do nfiles=nfiles+1 end
local port=8889

nixio.fs.mkdir('static')
for k,v in pairs(files) do
  local f=io.open('static/'..k,'w')
  f:write(v)
  f:flush()
  f:close()
end

http.hosts['localhost']={GET={}}
local site = http.hosts.localhost

site.GET['^/static/(.*)$'] = file.folder('static')
assert(http.serve(port))

function test1()
  print 'fetch all files'
  local n=0
  for name, content in pairs(files) do
		local req = {host='localhost',port=port,path='/static/'..name}
    http.fetch(req, function(res)
			assert(res and res.status==200)
			assert(res.body == content)
			n=n+1
			if n==nfiles then return test2() end
		end)
  end
end

function test2()
  print 'do a partial range request'
  local n=0
  for name, content in pairs(files) do
    local start, stop = 3, #content-3
		local req = {host='localhost',port=port,path='/static/'..name}
		req.head = {Range = {bytes = start..'-'..stop}}
    http.fetch(req, function(res)
      assert(res and res.status==206, 'Did not return 206: '..res.status)
			local expected = content:sub(start+1, stop+1)
			assert(res.body==expected, tc{'Does not match: ',res.body,' !! ', expected})
			n=n+1
			if n==nfiles then core.stop() end
		end)
  end
end

test1()
core.loop()
for k,v in pairs(files) do
  os.remove('static/'..k)
end
os.remove('static')
print('pass.')
