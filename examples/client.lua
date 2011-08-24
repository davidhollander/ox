local core = require'ox.core'
local http = require 'ox.http'
local html = require 'ox.html'

-- Web crawling example, in progress.
-- Request bodying parsing awaiting design decision before implementation.

function crawl(req, depth, attempts)
  http.fetch(req, function(res)
    if not res or res.status>=400 then
      if not attempts or attempts<3 then
        print('retrying',res.status, attempts)
        return ox.timer(10, function()
          return crawl(req, depth, (attempts or 0) + 1)
        end)
      end
    elseif res.status>=300 then
      local loc = res.head.Location
      if loc then
        local host, path = loc:match 'http://([^/]+)(.*)'
        print('redirecting', res.status, loc, host, path)
        if not host or host:match(req.host) then
          local req = {host=req.host, path=path or loc, head=req.head}
          return crawl(req, depth)
        end
      end
    else
      local dom = html.decode(res.body)
      print(html.gete(dom, 'title')[1])
      local links = html.geta(dom, 'a')
      for i,link in ipairs(links) do
        local url = link.a.href
        io.write(link.a[1], ' : ', url,'. ')
        local host, path = url:match 'http://([^/]+)(.*)'
        if not host or host:match(req.host) then
          local req = {host=req.host, path=path or url, head=req.head}
          crawl(req, n-1)
        end
      end
    end
  end)
end

local req = {
  host = 'http://www.google.com',
  path = '/',
  head = {['User-Agent']='Ox Client Example'}
}

crawl(req, 2)
core.loop()
