-- ox.file
-- Copyright (c) 2011 David Hollander
-- Released under the simplified BSD license, see LICENSE.txt

-- Controllers for sending files over http and utility functions

local data=require'ox.data'
local core=require'ox.core'
local http=require'ox.http'
local nixio=require'nixio',require'nixio.util'
local zlib=require'zlib'
local ti, tc =table.insert, table.concat
module(... or 'ox.file',package.seeall)

-- iterate to the end of the file
local function source_file(file)
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

-- iterate for N bytes of the file
local function source_partial(file,n)
  return function()
    if not file then return nil end
    if n>8192 then m=8192; n=n-8192
    elseif n>0 then m=n; n=0 end
    local chunk=file:read(m)
    if not chunk or n==0 then file:close() file=nil end
    return chunk
  end
end

-- wrap source with streaming GZIP compressor
local function compress(source)
  local filter=zlib.deflate()
  return function()
    if not source then filter=nil; return nil end
    local chunk=source()
    if not chunk then source=nil; return filter()
    else return filter(chunk) end
  end
end

-- cache a static response into memory using a file
function preload(path)
  local f=nixio.open(path)
  if not f then print("Could not cache: "..path) end
  local stats=f:stat()
  local body=f:readall()
  local res=table.concat {
    http.status_line[200],
    'Content-Length: ',#body,'\r\n',
    'Content-Type: ',mime_types[path:match('%.(%w+)$')] or 'text/plain','\r\n',
    "Last-Modified: ",http.datetime(stats.mtime),'\r\n',
    '\r\n',body,'\r\n'
  }
  f:close()
  body=nil f=nil stats=nil
  return function(c) core.finish(c, res) end
end	
-- cache a static response into memory for [timeout] duration
function cache(path, timeout)
  local mime = mime_types[path:match('%.(%w+)$')] or 'text/plain'
  local response_cache = data.cache_single(function(cb)
    local f=nixio.open(path)
    local stats=f:stat()
    local body=f:readall()
    cb(table.concat {
      http.status_line[200],
      'Content-Length: ',#body,'\r\n',
      'Content-Type: ',mime,'\r\n',
      'Last-Modified: ',http.datetime(stats.mtime),'\r\n\r\n',
      body,'\r\n'
    })
  end)
  return function(c) response_cache(function(res) core.finish(c, res) end) end
end
-- turn a folder into a HTTP file handler
-- does not support GZIP or partial requests
function folder_simple(dir)
  local dir=dir:match('^(.+)/?$')
  return function(c, path)
    local rh=c.res.head
    f=not path:match('%.%.') and nixio.open(dir..'/'..path)
    if not f then return c:reply(404) end
    local ext=path:match('%.(%w+)$')
    local mime=mime_types[ext] or 'application/octet-stream'
    rh['Content-Type']=mime
    local stats=f:stat()
    rh['Last-Modified']=http.datetime(stats.mtime)
    rh['Content-Length']= stats.size
    c:reply(200,source_file(f))
  end
end

--turn a folder into a HTTP file handler with streaming GZIP and partial request support
function folder(dir, config)
  local dir=dir:match('^(.+)/?$')
  return function(c,path)
    local reqh=c.req.head
    local resh=c.res.head
    local f = not path:match('%.%.') and nixio.open(dir..'/'..path)
    print('file.folder',f)
    if not f then return http.reply(c, 404) end
    local body
    local mime=mime_types[path:match('%.(%w+)$')] or 'application/octet-stream'
    local stats=f:stat()
    --http.header(c, 'Cache-Control','max-age=3600, must-revalidate')
    resh['Content-Type']=mime
    --resh['Accept-Ranges']='bytes'
    resh['Last-Modified']=http.datetime(stats.mtime)

    -- partial content
    if reqh.Range then
      local start, stop = reqh.Range:match('(%d+)%s*-%s*(%d+)')
      local start, stop = tonumber(start), tonumber(stop)
      print(start, stop, type(start), type(stop))
      local n = start and stop and stop - start + 1
      if not n or n<=0 then
        resh['Content-Range']= tc {'bytes */',stats.size}
        return http.reply(c, 416) -- bad request range
      else
        f:seek(start,'set')
        resh['Content-Range']= tc {'bytes ',start,'-',stop,'/',stats.size}
        resh['Content-Length']=n
        return http.reply(c, 206, source_partial(f, n))
      end
    end
    
    -- streaming compression
    if string.match(reqh['Accept-Encoding'] or '', 'deflate') then
      resh['Content-Encoding']='deflate'
      return http.reply(c, 200, compress(source_file(f)))
    else
      resh['Content-Length']=stats.size
      return http.reply(c, 200, source_file(f))
    end
  end
end

-- To add: functions for preloading folder into memory,
-- folder function that caches small GZIP files into memory

mime_types = {
  ez = "application/andrew-inset",
  atom = "application/atom+xml",
  hqx = "application/mac-binhex40",
  cpt = "application/mac-compactpro",
  mathml = "application/mathml+xml",
  doc = "application/msword",
  bin = "application/octet-stream",
  dms = "application/octet-stream",
  lha = "application/octet-stream",
  lzh = "application/octet-stream",
  exe = "application/octet-stream",
  class = "application/octet-stream",
  so = "application/octet-stream",
  dll = "application/octet-stream",
  dmg = "application/octet-stream",
  oda = "application/oda",
  ogg = "application/ogg",
  pdf = "application/pdf",
  ai = "application/postscript",
  eps = "application/postscript",
  ps = "application/postscript",
  rdf = "application/rdf+xml",
  smi = "application/smil",
  smil = "application/smil",
  gram = "application/srgs",
  grxml = "application/srgs+xml",
  mif = "application/vnd.mif",
  xul = "application/vnd.mozilla.xul+xml",
  xls = "application/vnd.ms-excel",
  ppt = "application/vnd.ms-powerpoint",
  rm = "application/vnd.rn-realmedia",
  wbxml = "application/vnd.wap.wbxml",
  wmlc = "application/vnd.wap.wmlc",
  wmlsc = "application/vnd.wap.wmlscriptc",
  vxml = "application/voicexml+xml",
  bcpio = "application/x-bcpio",
  vcd = "application/x-cdlink",
  pgn = "application/x-chess-pgn",
  cpio = "application/x-cpio",
  csh = "application/x-csh",
  dcr = "application/x-director",
  dir = "application/x-director",
  dxr = "application/x-director",
  dvi = "application/x-dvi",
  spl = "application/x-futuresplash",
  gtar = "application/x-gtar",
  hdf = "application/x-hdf",
  xhtml = "application/xhtml+xml",
  xht = "application/xhtml+xml",
  js = "application/x-javascript",
  skp = "application/x-koan",
  skd = "application/x-koan",
  skt = "application/x-koan",
  skm = "application/x-koan",
  latex = "application/x-latex",
  xml = "application/xml",
  xsl = "application/xml",
  dtd = "application/xml-dtd",
  nc = "application/x-netcdf",
  cdf = "application/x-netcdf",
  sh = "application/x-sh",
  shar = "application/x-shar",
  swf = "application/x-shockwave-flash",
  xslt = "application/xslt+xml",
  sit = "application/x-stuffit",
  sv4cpio = "application/x-sv4cpio",
  sv4crc = "application/x-sv4crc",
  tar = "application/x-tar",
  tcl = "application/x-tcl",
  tex = "application/x-tex",
  texinfo = "application/x-texinfo",
  texi = "application/x-texinfo",
  t = "application/x-troff",
  tr = "application/x-troff",
  roff = "application/x-troff",
  man = "application/x-troff-man",
  me = "application/x-troff-me",
  ms = "application/x-troff-ms",
  ustar = "application/x-ustar",
  src = "application/x-wais-source",
  zip = "application/zip",
  au = "audio/basic",
  snd = "audio/basic",
  mid = "audio/midi",
  midi = "audio/midi",
  kar = "audio/midi",
  mpga = "audio/mpeg",
  mp2 = "audio/mpeg",
  mp3 = "audio/mpeg",
  aif = "audio/x-aiff",
  aiff = "audio/x-aiff",
  aifc = "audio/x-aiff",
  m3u = "audio/x-mpegurl",
  ram = "audio/x-pn-realaudio",
  ra = "audio/x-pn-realaudio",
  wav = "audio/x-wav",
  pdb = "chemical/x-pdb",
  xyz = "chemical/x-xyz",
  bmp = "image/bmp",
  cgm = "image/cgm",
  gif = "image/gif",
  ief = "image/ief",
  jpeg = "image/jpeg",
  jpg = "image/jpeg",
  jpe = "image/jpeg",
  png = "image/png",
  svg = "image/svg+xml",
  svgz = "image/svg+xml",
  tiff = "image/tiff",
  tif = "image/tiff",
  djvu = "image/vnd.djvu",
  djv = "image/vnd.djvu",
  wbmp = "image/vnd.wap.wbmp",
  ras = "image/x-cmu-raster",
  ico = "image/x-icon",
  pnm = "image/x-portable-anymap",
  pbm = "image/x-portable-bitmap",
  pgm = "image/x-portable-graymap",
  ppm = "image/x-portable-pixmap",
  rgb = "image/x-rgb",
  xbm = "image/x-xbitmap",
  xpm = "image/x-xpixmap",
  xwd = "image/x-xwindowdump",
  igs = "model/iges",
  iges = "model/iges",
  msh = "model/mesh",
  mesh = "model/mesh",
  silo = "model/mesh",
  wrl = "model/vrml",
  vrml = "model/vrml",
  ics = "text/calendar",
  ifb = "text/calendar",
  css = "text/css",
  html = "text/html",
  htm = "text/html",
  asc = "text/plain",
  txt = "text/plain",
  rtx = "text/richtext",
  rtf = "text/rtf",
  sgml = "text/sgml",
  sgm = "text/sgml",
  tsv = "text/tab-separated-values",
  wml = "text/vnd.wap.wml",
  wmls = "text/vnd.wap.wmlscript",
  etx = "text/x-setext",
  mpeg = "video/mpeg",
  mpg = "video/mpeg",
  mpe = "video/mpeg",
  qt = "video/quicktime",
  mov = "video/quicktime",
  mxu = "video/vnd.mpegurl",
  avi = "video/x-msvideo",
  movie = "video/x-sgi-movie",
  ice = "x-conference/x-cooltalk",
}
