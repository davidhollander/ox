--templates.lua
--Original version by Zed Shaw: http://sheddingbikes.com/posts/1289384533.html

local VIEW_ACTIONS = {
  ['{%'] = function(code)
    return code
  end,
  ['{{'] = function(code)
      return ('table.insert(result, %s)'):format(code)
  end,

  ['{('] = function(code)
    return ([[ 
      if not children[%s] then
        children[%s] = Tir.view(%s)
      end
      table.insert(result, children[%s](getfenv()))
    ]]):format(code, code, code, code)
  end,

  ['{<'] = function(code)
    return ('table.insert(result, Tir.escape(%s))'):format(code)
  end,
}

local function compile_view(tmpl, name)
  local tmpl = tmpl .. '{}'
  local code = {'local result, children = {}, {}\n'}

  for text, block in string.gmatch(tmpl, "([^{]-)(%b{})") do
    table.insert(code, ('table.insert(result, [[%s]])'):format(text))
    local act = VIEW_ACTIONS[block:sub(1,2)]
    if act then
      table.insert(code, act(block:sub(3,-3)))
    end
  end

  table.insert(code, 'return table.concat(result)')

  code = table.concat(code, '\n')
  local func, err = loadstring(code, name)

  if err then
    assert(func, err)
  end

  return function(context)
    assert(context, "You must always pass in a table for context.")
    setmetatable(context, {__index=_G})
    setfenv(func, context)
    return func()
  end
end

local function renderer(d)
  local dir=d:match('(.+)/?')..'/'
  return setmetatable({},{
    __index=function(t,key)
      local tmpl=rawget(t,key) or false
      if not tmpl then
        local f=io.open(dir..key..'.html')
        if not f then return false end
        tmpl=compile_view(f:read('*a'),key)
        rawset(t,key,tmpl)
      end
      return tmpl
  end})
end
file2type={
  'html':'text/html',
  'json':'application/json',
  'js':'application/javascript',
}

function RenderResponse(c, path, data)
  f=io.open(path)
  if not f then return Error(c) end
  c.headers=file2type[path:match("\.(%w+)$")] or "text/plain"
  http.Respond(c,200,compile_view()
end

local function view(name)
  if os.getenv('PROD') then
    return compile_view(load_file(TEMPLATES, name), name)
  else
    return function (params)
      return compile_view(load_file(TEMPLATES, name), name)(params)
    end
  end
end

return {renderer=renderer}
