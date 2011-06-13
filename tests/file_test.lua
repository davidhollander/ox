local core=require'ox.core'
local http=require'ox.http'
local file=require'ox.file'

local port=8888
files={}
files['script.js']="alert('Hello');"
files['page.html']="<html><body>Hello</body></html>"

nixio.fs.mkdir('static')
for k,v in pairs(files) do
  assert(nixio.writefile('static/'..k,v))
end

http.GET['^/static/(.*)$'] = file.folder_handler('static')
assert(http.serve(port,http))

for k,v in pairs(files) do
  http.fetch {
    host = 'localhost',
    port = port,
    path = '/static/'..k,
    done = function(res)
      print(res.head['Content-Type'])
      assert(res.body==v)
    end
  }
end



core.loop()
