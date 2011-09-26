-- globtrie test

local lib = require 'ox.lib'
local get = lib.globtrie_get
local put = lib.globtrie_put


--CAPTURING
local R = {}
local x = {}
put(R, 'foo.net', 1)
put(R, 'foo.org', 2)
put(R, '*.com',   3)
put(R, 'foo.*',   4)

x = {get(R, 'foo.net')}
assert(#x==1 and x[1]==1)
x = {get(R, 'foo.org')}
assert(#x==1 and x[1]==2)
x = {get(R, 'foo.com')}
assert(#x==2 and x[1]==4 and x[2]=='com')
x = {get(R, 'foo.co')}
assert(#x==2 and x[1]==4 and x[2]=='co')
x = {get(R, 'baz.com')}
assert(#x==2 and x[1]==3 and x[2]=='baz')

local R = {}
put(R, 'static.google.com', 1)
put(R, '*.google.com',   2)

x = {get(R, 'static.google.com')}
assert(#x==1 and x[1]==1)
x = {get(R, 'foo.google.com')}
assert(#x==2 and x[1]==2 and x[2]=='foo')

local R = {}
put(R, '*', 1)
put(R, '*.*.com', 2)
put(R, '*.google.com', 3)
put(R, 'static.google.com', 4)
put(R, 'static.*.com', 5)
put(R, 'static.google.*', 6)

x = {get(R, 'foo.com')}
assert(#x==2 and x[1]==1 and x[2]=='foo.com')
x = {get(R, 'foo.foo.com')}
assert(#x==3 and x[1]==2 and x[2]=='foo' and x[3]=='foo')
x = {get(R, 'foo.google.com')}
assert(#x==2 and x[1]==3 and x[2]=='foo')
x = {get(R, 'static.google.com')}
assert(#x==1 and x[1]==4)
x = {get(R, 'static.foo.com')}
assert(#x==2 and x[1]==5 and x[2]=='foo')
x = {get(R, 'static.google.foo')}
assert(#x==2 and x[1]==6 and x[2]=='foo')

local R = {}
put(R, '/events', 1)
put(R, '/events/', 1)
put(R, '/events/*', 2)
put(R, '/events/*/foo', 3)
put(R, '/events/*/bar', 4)

x = {get(R, '/events')}
assert(#x==1 and x[1]==1)
x = {get(R, '/events/')}
assert(#x==1 and x[1]==1)
x = {get(R, '/events2')}
assert(#x==0 or #x==1 and not x[1])
x = {get(R, '/events/foo')}
assert(#x==2 and x[1]==2 and x[2]=='foo')
x = {get(R, '/events/bar')}
assert(#x==2 and x[1]==2 and x[2]=='bar')
x = {get(R, '/events/foo/foo')}
assert(#x==2 and x[1]==3 and x[2]=='foo')
x = {get(R, '/events/bar/bar')}
assert(#x==2 and x[1]==4 and x[2]=='bar')
print 'pass'
