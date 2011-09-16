local ox = require 'ox'
local ffi = require 'ffi'
local lib = require 'ox.lib'

os.execute 'rm *.test'

ox.split(1, function()
  print 'split'
  ox.daemon({}, function()
    print 'daemon'
    local f = io.open('__daemon__.test','w')
    for i=1,4 do
      f:write(i)
      f:flush()
      lib.sleep(1)
    end
    f:close()
  end)
end)

lib.sleep(2)
ox.kill()
local f = io.open '__daemon__.test'
print(f:read '*a')
lib.sleep(2)
print(f:read '*a')
os.execute 'rm *.test'

-- todo: test changing directory and umask
print 'pass'
