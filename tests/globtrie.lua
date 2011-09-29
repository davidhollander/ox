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

x, cap = get(R, 'foo.net')
assert(x==1 and #cap==0)
x, cap = get(R, 'foo.org')
assert(x==2 and #cap==0)
x, cap = get(R, 'foo.com')
assert(#cap==1 and x==4 and cap[1]=='com')
x, cap = get(R, 'foo.co')
assert(#cap==1 and x==4 and cap[1]=='co')
x, cap = get(R, 'baz.com')
assert(#cap==1 and x==3 and cap[1]=='baz')

local R = {}
put(R, 'static.google.com', 1)
put(R, '*.google.com',   2)

x, cap = get(R, 'static.google.com')
assert(#cap==0 and x==1)
x, cap = get(R, 'foo.google.com')
assert(#cap==1 and x==2 and cap[1]=='foo')

local R = {}
put(R, '*', 1)
put(R, '*.*.com', 2)
put(R, '*.google.com', 3)
put(R, 'static.google.com', 4)
put(R, 'static.*.com', 5)
put(R, 'static.google.*', 6)

x, cap = get(R, 'foo.com')
assert(#cap==1 and x==1 and cap[1]=='foo.com')
x, cap = get(R, 'foo.foo.com')
assert(#cap==2 and x==2 and cap[1]=='foo' and cap[2]=='foo')
x, cap = get(R, 'foo.google.com')
assert(#cap==1 and x==3 and cap[1]=='foo')
x, cap = get(R, 'static.google.com')
assert(#cap==0 and x==4)
x, cap = get(R, 'static.foo.com')
assert(#cap==1 and x==5 and cap[1]=='foo')
x, cap = get(R, 'static.google.foo')
assert(#cap==1 and x==6 and cap[1]=='foo')

local R = {}
put(R, '/events', 1)
put(R, '/events/', 1)
put(R, '/events/*', 2)
put(R, '/events/*/foo', 3)
put(R, '/events/*/bar', 4)

x, cap = get(R, '/events')
assert(#cap==0 and x==1)
x, cap = get(R, '/events/')
assert(#cap==0 and x==1)
x, cap = get(R, '/events2')
assert(not x)
x, cap = get(R, '/events/foo')
assert(#cap==1 and x==2 and cap[1]=='foo')
x, cap = get(R, '/events/bar')
assert(#cap==1 and x==2 and cap[1]=='bar')
x, cap = get(R, '/events/foo/foo')
assert(#cap==1 and x==3 and cap[1]=='foo')
x, cap = get(R, '/events/bar/bar')
assert(#cap==1 and x==4 and cap[1]=='bar')
print 'pass'
