local ox=require'ox'

--filterkeys
assert(json.encode(ox.filterkeys({key1=3,key2=4,key3=57},{'key1','key3'}))==json.encode({key1=3,key3=57}),'filterkeys')

--makecounter
local c=ox.makecounter()
c(50);c(57);c(100)
assert(c()==50+57+100,'makecounter')

mockrequest=table.concat({
'GET / HTTP/1.1',
'Host: localhost:8077',
'Connection: keep-alive',
'Accept: application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5',
'User-Agent: Mozilla/5.0 (X11; U; Linux x86_64; en-US) AppleWebKit/534.13 (KHTML, like Gecko) Ubuntu/10.10 Chromium/9.0.597.94 Chrome/9.0.597.94 Safari/534.13',
'Accept-Encoding: gzip,deflate,sdch',
'Accept-Language: en-US,en;q=0.8',
'Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3',
},'\r\n')..'\r\n'

mockview={'^/$',req={'user'}}
mockview.view=function(msg) return 'hello' end
mockhire='{%hire:{"root":{"1":"^/$","req":["user"],"cache":false}}%}'
print('OK')
