

function render(table)
end

function validate(t)
end

function ParseMultiPart(cbs)
  cbs.on_field_begin()
  cbs.on_field()
  cbs.on_field_end()
end

function StoreUpload(thread,filename,cb)
  f=io.open(filename,'w')
  if not f then return cb(false) end
  thread.body=ParseMultiPart{
    on_field_begin=function(name,filename)
      if filename then end
    end,
    on_field=function(bytes)
      if f then f:write(bytes)
      else qstrdecode(bytes) end
    end
  }
  thread.complete=function()
    f:close()
    cb(true)
  end
end

local function get_boundary(content_type)
  local boundary = string.match(content_type, "boundary%=(.-)$")
  return "--" .. tostring(boundary)
end

local function break_headers(header_data)
  local headers = {}
  for type, val in string.gmatch(header_data, '([^%c%s:]+):%s+([^\n]+)') do
    type = string.lower(type)
    headers[type] = val
  end
  return headers
end

local function read_field_headers(input, pos)
  local EOH = "\r\n\r\n"
  local s, e = string.find(input, EOH, pos, true)
  if s then
    return break_headers(string.sub(input, pos, s-1)), e+1
  else return nil, pos end
end

local function get_field_names(headers)
  local disp_header = headers["content-disposition"] or ""
  local attrs = {}
  for attr, val in string.gmatch(disp_header, ';%s*([^%s=]+)="(.-)"') do
    attrs[attr] = val
  end
  return attrs.name, attrs.filename and split_filename(attrs.filename)
end

local function read_field_contents(input, boundary, pos)
  local boundaryline = "\r\n" .. boundary
  local s, e = string.find(input, boundaryline, pos, true)
  if s then
    return string.sub(input, pos, s-1), s-pos, e+1
  else return nil, 0, pos end
end

local function file_value(file_contents, file_name, file_size, headers)
  local value = { contents = file_contents, name = file_name,
    size = file_size }
  for h, v in pairs(headers) do
    if h ~= "content-disposition" then
      value[h] = v
    end
  end
  return value
end

local function fields(input, boundary)
  local state, _ = { }
  _, state.pos = string.find(input, boundary, 1, true)
  state.pos = state.pos + 1
  return function (state, _)
     local headers, name, file_name, value, size
     headers, state.pos = read_field_headers(input, state.pos)
     if headers then
       name, file_name = get_field_names(headers)
       if file_name then
         value, size, state.pos = read_field_contents(input, boundary,
            state.pos)
         value = file_value(value, file_name, size, headers)
       else
         value, size, state.pos = read_field_contents(input, boundary,
            state.pos)
       end
     end
     return name, value
   end, state
end

local function parse_multipart_data(input, input_type, tab, overwrite)
  tab = tab or {}
  local boundary = get_boundary(input_type)
  for name, value in fields(input, boundary) do
    insert_field(tab, name, value, overwrite)
  end
  return tab
end


