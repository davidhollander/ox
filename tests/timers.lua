local ox = require 'ox' 
ox.at(ox.time - 1, function()
  assert(false,'this callback should not be set')
end)

local start = ox.time
ox.at(ox.time+2,function()
  print '2'
  assert(ox.time==start+2)
end)

ox.cron({sec=10}, function()
  assert(os.date('*t').sec==10)
  print 'cron'
  return ox.stop()
end)

ox.start()
print 'pass.'
