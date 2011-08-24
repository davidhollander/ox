local core = require 'ox.core'

core.at(core.time - 1, function()
	assert(false,'this callback should not be set')
end)

local start = core.time
core.timeout(2,function()
	print '2'
	assert(core.time==start+2)
end)

local times=0
core.cron({sec=10}, function()
	assert(os.date('*t').sec==10)
	print 'cron'
	times=times+1
	if times==2 then core.stop() end
end)

core.loop()
print 'pass.'
