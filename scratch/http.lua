function SendHeaders(c, status, body)
  local s=status_line[status]
  if not s then return Error(c) end
  local t={s}
  if c.headers then
    for k,v in pairs(c.headers) do table.insert(t,k..": "..v.."\r\n") end
  end
  table.insert(t,'\r\n')
  c.fd:send(table.concat(t))
end
function Respond(c, status, body)
  local s=status_line[status]
  if not s then return Error(c) end
  local t={s}
  if c.headers then
    for k,v in pairs(c.headers) do table.insert(t,k..": "..v.."\r\n") end
  end
  table.insert(t,'\r\n')
  if body then table.insert(t,body) table.insert(t,'\r\n') end
  core.SendAll(c,table.concat(t))
  print(c.req.path.."->Respond"..status.."->SendAll")
end
-- IntClient
-- Bypass http parsing to make an internal request
-- Maybe make connection an object to bypass Respond methods\faking a file descriptor
function IntClient(method, path, headers, data, cb)
  local c = {fd={}, headers=headers, req{data=data, path=path}}
  local b ={}
  function c.fd.send(self, msg, n)
    table.insert(b, msg) 
    return #msg
  end
  function c.fd.close(self)
    return cb(table.concat(b))
  end
  for path,fn in pairs(http[method]) do
    capture=req.path:match(path)
    if capture then
      local success, err = pcall(fn,c,capture)
      if not success then cb(nil) end
      break
    end
  end
end
