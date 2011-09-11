local fs = require 'ox.fs'

for fname in fs.gdir 'test/?.lua' do
  print(fname)
  loadfile(fname)()
end
