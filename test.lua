local fs = require 'nixio.fs'
local i=1
for name in fs.glob 'tests/*.lua' do
  local f = assert(io.open(name))
  local test = loadfile(name)
  print''
  print(i, name)
  print''
  test()
  i=i+1
end
print 'pass.'
