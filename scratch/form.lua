form={}

function form(...)
  local inputs={...}
  return function(data)
    local out={}
    if data then
      local errors={}
      for i=1,#inputs do
        #inputs[i](data)




joinform={}
joinform[1] = {
  html = function(data)
    return '<input name="user" type="text" value="', data,'"/>'
  end,
  validate = function(i)
    if not i then return "Required"
    elseif #i>32 then return "Must be less than 32"
    elseif #i<4 then return "Must be greater than 4"
    end
  end,
}
joinform[2] = {
  html = '<input name="pw" type="password" maxlength=32/>',
  validate = function(i)
    if not i then return 'Required'
    elseif #i>32 then return 'Must be less than 32'
    elseif #i<4 then return 'Must be greater than 4'
    end
  end
}
joinform[3] = {
  html = '<input name="pw2" type="password" maxlength=32/>'
  validate = function(i)
    if not i then return 'Required'
    end
  end
}
joinform.validate = function(t)
  if t.pw~=t.pw2 then return 'Passwords do not match'
  end
end
-----------------
joinform = form(
  input({ name="user", type="text", label="Username",
    validate = function(i)
      if not i.user then return "Required"
      elseif #i>32 then return "Must be under 32 characters"
      elseif #i<4 then return "Must be greater than 4 characters"
      end
    end
  },
  input { name="pw", type="pw"

------------------
joinform=form(
  text('Username',"user", {maxlength=32},function(i)
    if not i.user then return "Required"
    elseif #i>32 then return "Must be under 32 characters"
    elseif #i<4 then return "Must be greater than 4 characters"
    end
  end),
  password('Password','pw', {maxlength=32},function(i)
    if not i.pw then return "Required"
    elseif #i>32 then return "Must be less than 32 characters"
    elseif #i<4 then return "Must be greater than 4 characters"
    end
  end),
  password('Password (again)','pw2', {maxlength=32}, function(i)
    if i.pw~=i.pw2 then "Password did not match"
    end
  end)
)

eventform=form(
  text('Title', 'title', {maxlength=32}, function(i)
    if not i.title then return "Required"
    elseif #i.title>32 then return "Must be under 32 characters"
    elseif #i.title<4 then return "Must be greater than 4 characters"
    end
  end),
  text('

