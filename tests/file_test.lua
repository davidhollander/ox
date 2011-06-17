local core=require'ox.core'
local http=require'ox.http'
local file=require'ox.file'

local port=8888
files={}
files['script.js']="alert('Hello');"
files['page.html']="<html><body>Hello</body></html>"

nixio.fs.mkdir('static')
for k,v in pairs(files) do
  local f=io.open('static/'..k,'w')
  f:write(v)
  f:flush()
  f:close()
end

http.GET['^/static/(.*)$'] = file.folder('static')
assert(http.serve(port,http))

local n=0
for k,v in pairs(files) do
  http.fetch {
    host = 'localhost',
    port = port,
    path = '/static/'..k,
    success = function(res)
      print('success', res.body)
      print(res.head['Content-Type'])
      assert(res.body==v)
      n=n+1
      if n==2 then core.stop() end
    end
  }
end



core.loop()
for k,v in pairs(files) do
  os.remove('static/'..k)
end
os.remove('static')
print('pass.')
