-- ex_scrape.lua
-- web scraping example
-- tests http.Client, core.Connect, core.CallFork, core.SendA

local core=require'ox.core'
local http=require'ox.http'


function check_robots(host, cb)
	http.Client(host, 'GET','/robots.txt', {}, function(res)
		local avoid={}
		if res then
			for p in res:gmatch('Disallow:%s?([^%s]+)') do
				table.insert(avoid,'^'..p)
			end
		end
	end)
end

function print_links(host)
	http.Client(host, 'GET', '/', {
		['Host']=host	
	}, function(res)
		print('\n',res.status,host)
		if res.status==200 then
			for attr,content in res.body:gmatch('<a([^>]+)>([^<]+)</a>') do
				_, href = attr:match[[href%s?=%s?(['"])(.+)%1]]
				print(href,content)
			end
		end
	end)
end

--This is asynchronous, so whichever one finishes first prints first
print('scraping google.com and ycombinator.com asynchronously')
print_links('www.google.com')
print_links('www.ycombinator.com')
core.Loop()
