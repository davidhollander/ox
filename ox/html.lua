-- html.lua
-- Copyright David Hollander 2011
-- MIT License, see LICENSE

local ti, tc, tr = table.insert, table.concat, table.remove
local H={}
local function _dec_attr(s)
  local attr = {}
  s = s:gsub("(%w+)=([\"'])(.-)%2", function (k, _, v) attr[k]=v return '' end)
  s = s:gsub("(%w+)=(%w+)", function (k, v) attr[k]=v return '' end)
  s:gsub("(%w+)", function(k) attr[k]=k end)
  return attr
end

local _empty = {area=true,base=true,basefont=true,br=true,col=true,frame=true,hr=true,img=true,input=true,isindex=true,link=true,meta=true}
local no_nest = {table=true,tr=true,td=true,html=true,body=true,head=true,title=true,script=true}
local _parents = {
  body='html',tr='table',td='tr',title='head',meta='head',head='html',title='head'
}
---Nonstrict html parser. Always sticks elements in the DOM without raising errors. Inspired by Roberto's strict XML parser from LuaUsers wiki.
function H.decode(html)
  local i=1
  local dom = {}
  local node = dom
  while true do
    local h, k, close, e, attr, empty = html:find("<(/?)([%w:]+)(.-)(/?)>", i)
    if not h then break end
    local text = html:sub(i, h-1)
    if not text:match '^%s*$' then ti(node, text) end
    --insert
    if empty=='/' or _empty[e] then ti(node, {e=e, up=node, a=_dec_attr(attr)})
    --(ascend?), insert, descend
    elseif close=='' then
      if node.up and _parents[e] and _parents[e]~=node.e then
        repeat node=node.up until _parents[e]==node.e or not node.up
      end
      local x = {e=e, up=node, a=_dec_attr(attr)}
      ti(node, x)
      node = x
    --[[ascend, insert, descend
    elseif _parents[e] and _parents[e]~=node.e then
      while node.up do
        node=node.up
        if node.e==parents[e] then break end
      end
      ti(node, {e=e, up=node, a=_dec_attr(attr)})]]
    --ascend
    elseif close=='/' then
      while node.up do
        if node.e==e then node=node.up; break
        else node=node.up end
      end
    end
    i=k+1
  end
  return dom
end

local function _enc_attr(attr)
  local t ={}
  for k,v in pairs(attr) do
    if v==true then v=k end
    ti(t,('%s=%q'):format(k,v))
  end
  return tc(t,' ')
end

local function _enc(t, node)
  for i,node in ipairs(node) do
    if type(node)~='table' then ti(t, node)
    else
      ti(t,'<'); ti(t, node.e);
      if node.a then
        ti(t, ' '); ti(t,_enc_attr(node.a))
      end
      if #node<1 then
        ti(t,'/>')
      else
        ti(t, '>')
        _enc(t, node)
        ti(t, '</'); ti(t, node.e); ti(t, '>')
      end
    end
  end
end

---Encodes an html graph produced by decode as an XHTML string
function H.encode(dom)
  local out={}
  _enc(out, dom)
  return tc(out)
end

---Get all nodes where element == e
function H.gete(dom, e)
  local function _(O, x)
    for i, node in ipairs(x) do
      if type(node)=='table' then
        if node.e==e then ti(O, node) print('gete',H.encode(node))
        else _(O, node) end
      end
    end
  end
  local out = {}
  _(out, dom)
  return out
end

---Get all nodes where attribute k == v
function H.geta(dom, k, v)
  local function _(O, x)
    for i, node in ipairs(x) do
      if type(node)=='table' then
        if node.a and node.a[k]==v then ti(O, node) print('geta',H.encode(node))
        else _(O, node) end
      end
    end
  end
  local out = {}
  _(out, dom)
  return out
end

---Get all nodes where attribute k:match(v)
function H.matcha(dom, k, v)
  local function _(O, x)
    for i, node in ipairs(x) do
      if type(node)=='table' then
        if node.a and node.a[k] and node.a[k]:match(v) then ti(O, node)
        else _(O, node) end
      end
    end
  end
  local out = {}
  _(out, dom)
  return out
end

---Similar to os.time(t), but utc timezone correct if type(t)=='table'.
function H.utctime(t)
  if t then return os.time(t)+ os.date('%z')/100*60*60
  else return os.time() end
end

function H.uri_encode()
end


return H
