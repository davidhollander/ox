local http=require'ox.http'
do
  local str="hello x me = ss?q=23&23age Message /!@#& @("
  print('url_encode, url_decode')
  assert(str==http.url_decode(http.url_encode(str)))
  print('pass')

  print('qs_decode')
  local t = http.qs_decode('message='..http.url_encode(str)..'&bool=')
  assert(t.message==str and t.bool==true)
  print('pass')

  print('server, client, callfork')

end
