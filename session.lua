-- ox.session
-- Copyright (c) 2011 David Hollander
-- Released under the simplified BSD license, see LICENSE.txt

-- Session middleware for user authentication
-- Ex: http.Server(8080, http, {session.Check})
local http=require'ox.http'
local ti=table.insert
local tc=table.concat
local key_user={}
local user_key={}
local user_token={}
math.randomseed(os.time())

module('ox.session',package.seeall)

-- Check
function check(c)
  local u =c.req.jar.u
  if u then 
    key=tc{u, c.fd:getpeername(), c.req.head['User-Agent']}
    c.user=key_user[key]
  end
end

function csrf(c)
  if c.data and c.data.token~=user_token[c.user] then
    http.reply(c, 401, 'CSRF Failure')
  end
end

function login(c, user)
  local key, u
  repeat
    u=string.format('%x',math.random(10e10))
    key=tc{u,c.fd:getpeername(),c.req.head['User-Agent']}
  until not key_user[key]
  key_user[key]=user
  user_key[user]=key
  c.res.jar.u=u..'; httponly'
end

function logout(c)
  c.res.jar.u='deleted; expires='..http.datetime(0)
  local k = user_key[c.user]
  user_key[c.user]=nil
  key_user[k]=nil
end
