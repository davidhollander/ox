require 'lib'
local ox=require 'ox'
local templates=require 'templates'
local r=templates.renderer('views')
local tablei,tablec=table.insert,table.concat
local function qstrdecode(qstr)
  local data={}
  for k,v in qstr:gmatch('([%w%d]+)=([%w%d]*)') do
      data[k]=v or true
  end
  return data
end
local function Respond(client,...)
  table.insert(arg,1,'HTTP/1.1 200 OK\r\nContent-type:text/html\r\n\r\n')
  table.insert(arg,'\r\n')
  client.out=table.concat(arg)
  client.events=nixio.poll_flags('out')
end
local function Response(client,headers,...)
  local out={}
  tablei(out,"HTTP/1.1 200 OK\r\n")
  for k,v in pairs(headers) do
    tablei(out,k) tablei(out,': ') tablei(out,v) tablei(out,'\r\n')
  end
  tablei(out,'\r\n')
  for i=1,#arg do tablei(out,arg[i]) end
  tablei(out,'\r\n')
  client.out=tablec(out)
  print(client.out)
  client.events=nixio.poll_flags('out')
end
local function NotFound(client)
    client.out="HTTP/1.1 404 Not Found\r\n\r\n"
    client.events=nixio.poll_flags('out')
end

local HTTP={GET={},POST={}}
HTTP.GET['^/static/([^/]+)$']=function(client,capture)
  GetStream('rpc://static/'..capture,function(status,chunk)
end
HTTP.GET['^/$']=function(client)
  Respond(client,r.echo(client.req))
end
HTTP.POST['^/$']=function(client)
  local d=client.data
  if d.email:match('^%w+@%w+\.%w+$') then
    Post('rpc://mailer/welcome',{to=d.email},
      function(status)
        if status then Respond(client,'Sent')
        else Respond(client,'Could not send')
        end
      end
    )
  else Respond(client,'Improper Email')
  end
end

ox.httpserver(8080,HTTP)
ox.loop()

--[[
GET['^/betaateb$']=function(client)
    if client.user then
        Response(client,'Welcome '..client.user) 
    else
        Cache('landingpage',false,r.landing,partial(Response,client))
    end
end
POST['^/login$']=function(client)
    local data=qstrdecode(client.req.body)
    if #data.login<5 or #data.pass<5 then
        Response(r.header,'too short',r.footer)
    else
        Get('data://auth',{user=data.login},
            function(obj)
                if not obj then
                    Response(r.header,'user does not exist',r.footer)
                else
                    Login(client,data.login)
                    Redirect('/') end end) end end

POST['^/join$']=function(client)
    local data=qstrdecode(client.req.body)
    if #data.login<5 or #data.pass<5 or data.pass~=data.pass2 then
        Response(client,r.header,'Too Short or Not Match',r.footer)
    else
        Get('data://auth',{user=data.login},
            function(obj)
                if obj then
                    Response(client,r.header,'user already exists',r.footer)
                else
                    DataPut('auth',{user=data.login,pass=hashify(data.pass)},
                        function(bool)
                            if not bool then
                                Response(client,r.header,'failed',r.footer)
                            else
                                DoLogin(client,data.login)
                                Redirect(client,'/') end end) end end) end

HTTP.GET['.']=function(client)
    Get('http://www.google.com'..client.req.url,
        function(data) Response(client,data) end) end

RPC.GET['stats']=function(client)
    Respond(client,'No Stats') end

RPC.GET['(user_info)/([^/]+)']=function(conn,method,id)
    Get({'rpc://',nodeify(id),method,id},
        function(data)
            Respond(conn,data) end) end

HTTP.GET['^/user/([^/]+)$']=function(client,id)
    local res=ChunkedResponse(client,4)
    CacheGet('user_info'..id, --get cache else
        Get('rpc://data/user_info/'..client.user,
            function(data)
                if not data then CacheClear('user_info'..id)
                else CachePut('user_info'..id,10,r.user_info(data)) end end),
        function(cache)
            if not cache then NotFound()
            else res(cache,1) end end)
    CacheGet('followers'..id,10,
        Get('rpc://data/followers',{user=id},
            function(data)
                if not data then CacheClear('user_info'..id)
                else CachePut('user_info'..id,r.user_info(data)) end end),
        function(cache)
            if not cache then NotFound()
            else res(cache,2) end end)
    CacheGet('actions'..client.user,10,
        Get('rpc://data/followers',{user=client.user},
            function(data)
                if not data then CacheClear('user_info'..id)
                else CachePut('actions'..client.user,r.user_actions(data)) end end),
        function(cache)
            if not cache then NotFound()
            else res(cache,3) end end) end

RPC.GET['followers/(.+)']=function(client,id)
    RPCRespond(
        db.followers:get(key)) end

RPC.PUT['followers/(.+)']=function(client,id)
    RPCRespond(
        db.followers:put(client.data.key,client.data.value)) end

RPC.POST['followers/(.+)']=function(connection,id) end
    RPCRespond(
        db.followers:put(client.data.key,client.data.value)) end

--Cache
local cache={}
local cache_expires={}
local cache_callbacks={}
function CacheGet(key,f_update,f_cb)
    local x=cache_expires[key]
    if type(x)=='number' and x>os.time() or x then f_cb(cache[key])
    else
        f_update()
        table.insert(cache_callbacks[key],f_cb)
    end
end

function CachePut(key,time,value)
    cache[key]=value
    cache_expires[key]=type(time)=='number' and time+os.time() or time
    local cbs=cache_callbacks[key]
    if cbs then for i,cb in ipairs(cbs) do cb(value) end end
    cache_callbacks[key]={}
end

function CacheClear(key)
    local cbs=cache_callbacks[key]
    if cbs then for i,cb in ipairs(cbs) do cb(false) end end
    cache_callbacks[key]=nil
    cache_timestamp[key]=nil
    cache[key]=nil
end]]
