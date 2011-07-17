local core = require'ox.core'
local http = require'ox.http'
local session = require'ox.session'
http.GET['/'] = function(c)
  session
end
http.POST['/']=function(c)


end
