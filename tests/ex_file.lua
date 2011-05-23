local core = require 'ox.core'
local http = require 'ox.http'
local file = require 'ox.file'

http.GET['^/$'] = file.CacheSingle('file.html')

http.Server(8080,http)
print('Running on',8080)
core.Loop()
