local ffi = require 'ffi'
local ox = require 'ox'
local L = require 'ox.lib'
local S= require'ox.sys'

local charptr = ffi.typeof('char [?]')

local ti, tc = table.insert, table.concat
local readln = ox.readln
local j=0
function context(chunks)
  local name = '__test__'..j
  j=j+1
  f = io.open(name,'w')
  for i,v in ipairs(chunks) do
    f:write(v)
  end
  f:flush()
  f:close()
  return assert(ox.open(name,'r'))
end

local test_status = {}
function assertA(str)
  local n = #test_status + 1
  ti(test_status, 0)
  return function(c, line)
    print(n, line)
    assert(line==str, ('Test %d: %s != %s'):format(n,line or 'nil',str or 'nil'))
    test_status[n]=1
  end
end

-- TEST
--

print 'test'
local i=0
c = context {'abcdef\r\n'}
readln(c, 30, assertA 'abcdef')

c = context {'abcdef\r\nbar'}
readln(c, 30, assertA'abcdef')

c = context {'abcdef','\r\nbar'}
readln(c, 30, assertA'abcdef')

c = context {'abcdef\r','\nbar'}
readln(c, 30, assertA'abcdef')

c = context {'abcdef\r\n','bar'}
readln(c, 30, assertA'abcdef')

c = context {'abcdef','\r\n','bar'}
readln(c, 30, assertA'abcdef')

c = context {'abcdef','\r','\n','bar'}
readln(c, 30, assertA'abcdef')

c = context {'abcdef\r\n','bar\r\n'}
print('C',c)
readln(c, 30, function(c,line)
  print('LINE', line)
  assert(line=='abcdef')
  readln(c, 30, function(c, line) assert(line=='bar') end)
end)

c = context {'hello','\r\n','world','\r\n'}
readln(c, 30, function(c,line)
  print('LINE', line)
  assert(line=='hello')
  readln(c, 30, function(c, line) assert(line=='world') end)
end)

c = context {'hello\r','\n','world\r','\n'}
readln(c, 30, function(c,line)
  print('LINE', line)
  assert(line=='hello')
  readln(c, 30, function(c, line) assert(line=='world') end)
end)

c = context {'\r','\n'}
readln(c, 0, assertA'')

c = context {'abcdefghijklmnopqrs\r\n'}
readln(c, 2, assertA(nil))
print(i)
local lines = {
  'GET /favicon.ico HTTP/1.1',
  'Host: localhost:8096',
  'Connection: keep-alive',
  'Accept: */*',
  'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebkit/535.1'..
  ' (KHTML, like Gecko) Chrome 13.0.782.218 Safari/535.1',
  'Accept-Encoding: gzip,deflate,sdch',
  'Accept-Language: en-US,en;q=0.8',
  'Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3',
  '',
  '',
}

c = context {tc(lines,'\r\n')}
local k = 1
local function cb(c, line)
  print(line)
  assert(line==lines[k])
  k=k+1
  return k<=#lines and readln(c, 2048, cb)
end
readln(c, 2048, cb)

ox.at(ox.time+1, ox.stop)
ox.start()

print 'test results:'
local ok , fail = {}, {}
for i,v in ipairs(test_status) do
  if v==1 then ti(ok, i) else ti(fail, i) end
end
print 'pass'
print(tc(ok,', '))
if #fail>0 then
  print 'fail'
  print(tc(fail,', '))
end
