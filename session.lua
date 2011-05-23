-- ox.session
-- Copyright (c) 2011 David Hollander
-- Released under the simplified BSD license, see LICENSE.txt

-- Session middleware for user authentication
-- Ex: http.Server(8080, http, {session.Check})
local http=require'ox.http'

local keys={}
local users={}
math.randomseed(os.time())

module('ox.session',package.seeall)

-- Check
function Check(c)
  local h=c.req.headers
  if not h.Cookie then return end
  local u=h.Cookie:match('u=(%w+)')
  if u then 
    key=table.concat{u,c.fd:getpeername(),h['User-Agent']}
    c.user=users[key]
  end
end

function Login(c,user)
  local key, u
  repeat
    u=string.format('%x',math.random(10e10))
    key=table.concat{u,c.fd:getpeername(),c.req.headers['User-Agent']}
  until not keys[key]
  users[key]=user
  keys[user]=key
  http.SetHeader(c,'Set-Cookie','u='..u..'; httponly')
end

function Logout(c)
  http.SetHeader(c,'Set-Cookie','u=deleted; expires=Thu, 01-Jan-1970 00:00:01 GMT;')
  local k = keys[c.user]
  keys[c.user]=nil
  users[k]=nil
end
