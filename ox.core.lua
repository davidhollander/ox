---Testing luadoc
--I am testing luadoc and github pages
--Will update this shortly
--@param name (optional) defaults to "world"
function hello(name)
  name=name or 'world'
  local out='hello '..name
  print(out)
  return out
end
