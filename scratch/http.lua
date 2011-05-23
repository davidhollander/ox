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

