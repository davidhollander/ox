local core=require'core'
local lhp=require'http.parser'
local wsreq=require'wsapi.request'

function GetUploads(thread,cb)
  local length=tonumber(thread.headers['Content-Length']) or 0
  if length > 0 then
    thread.on_body=parse_multipart_data
  end
end


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
        GetUploads(thread,3, )
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
