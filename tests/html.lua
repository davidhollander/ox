local html = require 'ox.html'

local page = [[
<html>
  <head><meta></head>
  <body>
    <input type='checkbox' class=world checked>
    <input name='field' type='text'/>
    <div>
      <br>hello<br/>world<br>
    </div>
    <br/>
  </body>
</html>]]

function test(dom)
  assert(#dom==1)
  assert(dom[1].e=='html')
  assert(#dom[1]==2)
  assert(dom[1][1].e=='head')
  assert(dom[1][2].e=='body')
  local t = assert(dom[1][2][1].a)
  assert(t.type=='checkbox')
  assert(t.class=='world')
  assert(t.checked)
  assert(dom[1][2][2].e=='input')
  local div = assert(dom[1][2][3])
  assert(#div==5)
  assert(div[2]=='hello')
  assert(div[4]=='world')
end

print 'decode'
local dom = html.decode(page)
test(dom)

print 'encode'
local dom = html.decode(html.encode(html.decode(page)))
test(dom)

print 'gete'
local results = html.gete(dom, 'input')
assert(#results==2)

print 'geta'
local results = html.geta(dom, 'class', 'world')
assert(#results==1,'results: '..#results)
assert(results[1].e=='input')

print 'matcha'
local page2 = '<input name="form1"/><input name="form2"/><input name="orm3"/>'
local dom = html.decode(page2)
local results = html.matcha(dom, 'name', 'form')
assert(#results==2)

print 'utctime'
local t, now = os.date '!*t', os.time()
local now2 = html.utctime {year=t.year, month=t.month,day=t.day,hour=t.hour,
  min=t.min,sec=t.sec}
assert(now2-now ==0 )
print 'pass.'
