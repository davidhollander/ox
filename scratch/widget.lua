widget={}

function widget.concat(...)
  local children={...}
  return function(...)
    local params={...}
    local out={}
    for i=1,#children do
      table.insert(out,children[i](unpack(params)))
    end
    return table.concat(out)
  end
end


renderjoin=widget.concat(
  function(data) return '<input'
  end
) 
