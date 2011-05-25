-- ox.http
-- Copyright (c) 2011 David Hollander
-- Released under the simplified BSD license, see LICENSE.txt

-- an http server and utility functions

local core=require 'ox.core'
local lhp=require 'http.parser'
module('ox.http',package.seeall)

status_line={
  [200]="HTTP/1.1 200 OK\r\n",
  [201]="HTTP/1.1 201 Created\r\n",
  [206]="HTTP/1.1 206 Partial Content\r\n",
  [303]="HTTP/1.1 303 See Other\r\n",
  [400]="HTTP/1.1 400 Bad Request\r\n",
  [401]="HTTP/1.1 401 Unauthorized\r\n",
  [404]="HTTP/1.1 404 Not Found\r\n",
  [500]="HTTP/1.1 500 Internal Server Error\r\n",
}
GET,PUT,POST,DELETE={},{},{},{}

-- url_decode, url_encode
-- from WSAPI https://github.com/keplerproject/wsapi/blob/master/src/wsapi/request.lua
function url_decode(str)
  if not str then return nil end
  str = string.gsub (str, "+", " ")
  str = string.gsub (str, "%%(%x%x)", function(h) return string.char(tonumber(h,16)) end)
  str = string.gsub (str, "\r\n", "\n")
  return str
end
function url_encode(str)
  if not str then return nil end
  str = string.gsub (str, "\n", "\r\n")
  str = string.gsub (str, "([^%w ])",
        function (c) return string.format ("%%%02X", string.byte(c)) end)
  str = string.gsub (str, " ", "+")
  return str
end

-- qs_decode
-- Parses query strings and forms
function qs_decode(qstr)
  local t={}
  for k,v in string.gmatch(qstr, "([^&=]+)=([^&=]*)&?") do
    if #v>0 then t[url_decode(k)] = url_decode(v)
    else t[url_decode(k)] = true end
  end
  return t
end

function htmlquote(text)
  text=text:gsub("&","&amp;")
  text=text:gsub("<","&lt;")
  text=text:gsub(">","&gt;")
  text=text:gsub("'","&#39;")
  text=text:gsub('"',"&quot;")
  return text
end

function SetHeader(c, key, value)
  c.headers=c.headers or {}
  c.headers[key]=value
end

-- Respond
function Respond(c, status, body)
  local s=status_line[status]
  local t={s}
  if c.headers then
    for k,v in pairs(c.headers) do table.insert(t,k..": "..v.."\r\n") end
  end
  table.insert(t,'\r\n')
  if type(body)=='function' then
    core.SendSourceEnd(c, table.concat(t), body, '\r\n')
  else
    table.insert(t,body)
    table.insert(t,'\r\n')
    core.SendEnd(c,table.concat(t))
  end
end

-- Sets the Content-Length header before responding
function RespondFixed(c, status, body)
  local s=status_line[status]
  local t={s}
  if not c.headers then c.headers={} end
  c.headers['Content-Length'] = #body
  for k,v in pairs(c.headers) do table.insert(t,k..': '..v..'\r\n') end
  table.insert(t, '\r\n')
  table.insert(t, body)
  table.insert(t, '\r\n')
  core.SendEnd(c,table.concat(t))
end

local function chunkwrap(source)
  return function()
    local m=source()
    return table.concat{string.format('%x',#m),'\r\n',m,'\r\n'}
  end
end
-- RespondChunked, for streaming source without buffering
function RespondChunked(c, status, body)
  local s=status_line[status]
  local t={s}
  if not c.headers then c.headers={} end
  c.headers['Transfer-Encoding'] = 'Chunked'
  for k,v in pairs(c.headers) do table.insert(t,k..': '..v..'\r\n') end
  core.SendSourceEnd(c, table.concat(t), chunkwrap(source), '\r\n')
end

-- Server
-- Create a server on [port] using [views]
-- [views] contains a subtable for each HTTP method.
-- Each HTTP method table contains url patterns mapped to functions.
function Server(port,views,mware)
  return core.Serve(port,function(c)
    c.req={headers={}}
    local req=c.req; local done=false; local formbuffer={}
    local parser=lhp.request{
      on_url=function(url) req.url=url end,
      on_path=function(path) req.path=path end,
      on_header=function(key,val) req.headers[key]=val end,
      on_query_string=function(qstr) req.qstr=qs_decode(qstr) end,
      on_fragment=function(frag) req.frag=frag end,
      on_body=function(body) table.insert(formbuffer, body) end,
      on_message_complete=function()
        req.data=qs_decode(table.concat(formbuffer))
        done=true
      end,
      on_headers_complete=function()
        local ct=req.headers['Content-Type']
        if ct~="application/x-www-form-urlencoded" then done=true end
      end
    }
    core.OnRead(c,function(c)
      local data=c.fd:recv(1024)
      if data==false then return 
      elseif data==nil or data=='' or parser:execute(data)==0 then
        c.fd:close()
        return 'close'
      elseif done then
        if mware then for i=1,#mware do mware[i](c) end end
        local capture
        for path,fn in pairs(views[parser:method()]) do
          capture=req.path:match(path)
          if capture then
            local success,err=pcall(fn,c,capture)
            if not success then Respond(c, 500, err); core.Log(500,err) end
            break
          end
        end
        if not capture then Respond(c, 404) end
      end
    end)
  end)
end

-- Client
-- Make an asynchronous HTTP Request and buffer response body
-- on_message_complete callback is not getting triggered for some reason
function Client(host, port, method, url, headers, cb)
  return core.Connect(host, port, function(c)
    local t={method,' ',url," HTTP/1.1\r\n"}
    for k,v in pairs(headers) do
      table.insert(t, k..': '..v..'\r\n')
    end
    table.insert(t, '\r\n')
    local req=table.concat(t)
    local res={headers={},body={}}
    local done=false
    local parser=lhp.response{
      on_header=function(key,val) res.headers[key]=val end,
      on_body=function(chunk,e) print('onbody',chunk,e) table.insert(res.body,chunk) end,
      on_message_complete=function() print('msg complete') done=true end,
      on_headers_complete=function() print('headers complete') end,
    }
    core.SendReq(c,req)
    core.OnRead(c,function(c)
      local data=c.fd:recv(8192)
      if data==false then return 
      elseif data==nil or data=='' or parser:execute(data)==0 or done then
        res.status=parser:status_code();
        res.body=table.concat(res.body)
        c.fd:close()
        cb(res)
        return 'close'
      end
    end)
  end)
end
