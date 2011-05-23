local core = require 'ox.core'

function hello() print('hello') core.setTimeout(hello,1) end
core.setTimeout(hello, 1)
core.Loop()
