local core=require'core'
local lhp=require'http.parser'



function ParseUpload(cb)
  local name, filename
  local buffer=''
  return function(bytes)
    buffer=buffer and bytes
    if #buffer>100 then
      name,filename=buffer:match([[
        Content-Disposition: form-data; name="(%w+)"; filename="(%w+)"]])
        if not name and #buffer>200 then cb(false)
        else 
    end
  end
end

function ParseUpload(cb,boundary,path)
  local sink
  local buffer=''
  local f

  local function on_disposition(value)
    print("content-disposition")
    local name=value:match('[^e]name="(%w)+"')
    local filename=value:match('filename="(%w)+"')
    if filename then
      sink=io.open(path..filename,'w')
      f=store
    end
  end

  local function on_type(value)
    print("content-type")
  end

  --get Content-Disposition and Content-Type
  --if filename, set sink and goto store 
  local function findheaders(bytes)
    buffer:'\r\n'
    buffer=buffer..bytes
    local start,stop,k,v=buffer:find('([%w-]+):%s(.+)\r\n')
    if key=="Content-Disposition" then on_disposition(value)
    elseif key=="Content-Type" then on_type(value) end
  end

  --store
  --on boundary, close
  local function store(bytes)
    buffer=buffer..bytes
    local start,stop=buffer:find(boundary)
    if not start then
      sink:write(buffer:sub(1,#buffer-#boundary))
      buffer=buffer:sub(#buffer-#boundary,#buffer)
    else
      sink:write(buffer:sub(1,start))
      sink:close()
      buffer=buffer:sub(stop,#buffer)
      f=findheaders
    end
  end
  --after first boundary, findheaders
  local function findboundary(bytes)
    buffer=buffer..bytes 
    local start,stop=buffer:find(boundary)
    if not start then cb(false) end
    buffer=buffer:sub(#boundary,buffer)
    f=findheaders
    f()
  end
  
  f=findboundary
  return function(bytes) f(bytes) end
end
]]

function TestServer(port)
  return core.Serve(port,function(thread)
    local thread.headers={}
    local parser=lhp.request{
      on_url=function(url) print('on_url',url) end,
      on_path=function(path) print('on_path',path) end,
      on_header=function(key,value)
        thread.headers[key]=value
        print('on_header',key,value)
      end,
      on_query_string=function(qstr) print('qstr',qstr) end,
      on_fragment=function(frag) print('on_fragment',frag) end,
      on_body=function(body) print('body',body) end,
      on_headers_complete=function() print('on_headers_complete')
        local boundary=thread.headers['Content-Type']:match('multipart/form-data;%s?boundary=([-%d]+)')
        GetUploads(thread,3, 
      end,
      on_message_begin=function() print('on_message_begin') end,
      on_headers_complete=function() print('on_headers_complete') end,
    }
    core.OnRead(thread,function(thread)
      local data=thread.fd:recv(1024)
      if data==false then return
      elseif data==nil or data=='' or parser:execute(data)==0 then return 'close'
      elseif done then
        thread.fd:close()
        return 'close'
      end
    end)
  end)
end

TestServer(8888)
core.Loop()
