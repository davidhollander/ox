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
  local u = http.cookie(c, 'u')
  if u then 
    key=tc{u, c.fd:getpeername(), h['User-Agent']}
    c.user=key_user[key]
  end
end

function csrf(c)
  if c.data and c.data.token~=user_token[c.user] then
    http.Respond(c, 401, 'CSRF Failure')
  end
end

function login(c, user)
  local key, u
  repeat
    u=string.format('%x',math.random(10e10))
    key=table.concat{u,c.fd:getpeername(),c.req.headers['User-Agent']}
  until not keys[key]
  key_user[key]=user
  user_key[user]=key
  http.cookie(c, 'u', u..'; httponly')
end

function logout(c)
  http.cookie(c,'u','deleted; expires=Thu, 01-Jan-1970 00:00:01 GMT;')
  local k = usertokey[c.user]
  user_key[c.user]=nil
  key_user[k]=nil
end
