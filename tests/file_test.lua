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

http.GET['^/static/(.*)$'] = file.folder('static')
assert(http.serve(port,http))

function test1()
  print 'fetch all files'
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
        if n==nfiles then return test2() end
      end
    }
  end
end

function test2()
  print 'do a partial range request'
  local n=0
  for k,v in pairs(files) do
    local start, stop = 3, #v-3
    http.fetch {
      host = 'localhost',
      port = port,
      head = {Range=tc{'bytes=',start,'-',stop}},
      path = '/static/'..k,
      success = function(res)
        assert(res.status==206,'Did not return 206: '..res.status)
        local expected = v:sub(start+1,stop+1)
        assert(res.body==expected, tc{'Does not match: ',res.body,' !! ', expected})
        n=n+1
        if n==nfiles then core.stop() end
      end
    }
  end
end

test1()
core.loop()
for k,v in pairs(files) do
  os.remove('static/'..k)
end
os.remove('static')
print('pass.')
