-- ox.file
-- Copyright (c) 2011 David Hollander
-- Released under the simplified BSD license, see LICENSE.txt

-- Controllers for sending files over http and utility functions

local core=require'ox.core'
local http=require'ox.http'
local nixio=require'nixio',require'nixio.util'
local zlib=require'zlib'
local mimetypes=(require'ox.mime').types

module('ox.file',package.seeall)

-- SourceFile, SourcePartial, Compress
-- Loosely based on LTN12 sources
-- See http://lua-users.org/wiki/FiltersSourcesAndSinks

-- Source File
-- Iterate to the end of the file
function SourceFile(file)
  return function()
    if not file then return nil end
    local chunk=file:read(8192)
    if not chunk or chunk=='' then
			file:close()
			file=nil
			return nil
		end
    return chunk
  end
end

-- Source Partial
-- Iterate for N bytes of the file
function SourcePartial(file,n)
  return function()
    if not file then return nil end
    if n>8192 then m=8192; n=n-8192
    elseif n>0 then m=n; n=0 end
    local chunk=file:read(m)
    if not chunk or n==0 then file:close() file=nil end
    return chunk
  end
end

function Compress(source)
  local filter=zlib.deflate()
  return function()
    if not filter then return nil end
    local chunk=filter(source())
    if not chunk then filter=nil end
    return chunk
  end
end

-- partialseek
--If Range header is correct, seek file and returns bytes to read
local function partialseek(f,rangeheader)
  if not rangeheader then return nil end
  local start,stop=rangeheader:match('(%d+)%s*-%s*(%d+)')
  if start and stop then
    start=tonumber(start);stop=tonumber(stop)
    local toread=stop-start
    if toread>0 and f:seek(start,"set") then
      return toread
    end
  end
  return nil
end

-- CacheSingle
-- Cache a static response into memory using a file
function CacheSingle(path)
	local f=nixio.open(path)
	if not f then print("Could not cache: "..path) end
	local stats=f:stat()
	local body=f:readall()
	local res=table.concat {
		http.status_line[200],
		'Content-Length: ',#body,'\r\n',
		'Content-Type: ',mimetypes[path:match('%.(%w+)$')] or 'text/plain','\r\n',
		"Last-Modified: ",os.date("!%a, %d %b %Y %H:%M:%S GMT", stats.mtime),'\r\n',
		'\r\n',body,'\r\n'
	}
	f:close()
	body=nil f=nil stats=nil
	return function(c) core.SendEnd(c, res) end
end	
-- ServeSingle
-- Checks if file has changed each request and recaches
function ServeSingle(path)
	local res
	local mtime
	local function cache(f) 
		res=table.concat {
			http.status_line[200],
			"Last-Modified: ",os.date("!%a, %d %b %Y %H:%M:%S GMT", mtime),'\r\n',
			'Content-Type: ',mimetypes[path:match('%.(%w+)$')] or 'text/plain','\r\n',
			'\r\n',
			f:readall(),
			'\r\n'
		}
	end
	local function check()
		local f=nixio.open(path)
		local d=f:stat().mtime
		if d~=mtime then mtime=d; cache(f) end
	end
	return function(c) check() core.SendEnd(c, res) end
end


-- CacheFolder
-- ServeSingle
-- ServeFolder

-- SimpleHandler
-- Serves files from a directory without cacheing
-- Only supports 200 and 404, Content-Type
function SimpleHandler(dir)
	local dir=dir:match('^(.+)/?$')
	return function(c, path)
		if path:match('%.%.') then http.Respond(c, 404) end
		f=nixio.open(dir..'/'..path)
		if not f then return http.Respond(c, 404) end
    local ext=path:match('%.(%w+)$')
    local mime=mimetypes[ext] or 'application/octet-stream'
		print(mime,ext)
    http.SetHeader(c,'Content-Type',mime)
		local stats=f:stat()
    http.SetHeader(c,'Last-Modified',os.date("!%a, %d %b %Y %H:%M:%S GMT",
			stats.mtime))
		http.SetHeader(c,'Content-Length',stats.size)
		http.Respond(c,200,SourceFile(f))
	end
end

--File Handler
--Turns a folder into a HTTP file handler
function FileHandler(dir,cache)
  return function(c,path)
    --Check for existence
    f=nixio.open(dir..path)
    if not f then return http.Respond(c,404) end
    --Set cache headers
    --http.SetHeader('Cache-Control','max-age=3600, must-revalidate')
    --Negotiate content-type
    local ext=path:match('%.(%w+)$')
    local mime=mimetypes[ext] or 'application/octet-stream'
    http.SetHeader(c,'Content-Type',mime)
    
		local stats=f:stat()
    http.SetHeader(c,'Last-modified',os.date("!%a, %d %b %Y %H:%M:%S GMT",
      stats.mtime))
    --Negotiate response type
    local rangeread=partialseek(f,http.GetHeader(c,'Range'))
    local status=rangeread and 206 or 200
    local source=rangeread and SourcePartial(f,rangeread) or SourceFile(f)

    --[[Negotiate response encoding
    local body
    if c.req.header['Accept-Encoding']:match('gzip') then
      body=Compress(source)
      http.SetHeader('Content-Encoding','gzip')
    else body=source end]]
    body=source
       
    --Respond
    http.SendHeaders(c,status)
    core.SendSource(c,source)
  end
end
