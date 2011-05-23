
do
  local t1=os.clock()
  for i=1,100000 do
    local str=table.concat{"hello","world","hello","world","hello","world","hello","hello","world","hello","world"}
  end
  print("table concat",os.clock()-t1)
  local t2=os.clock()
  for i=1,100000 do
		local str="hello".."world".."hello".."world".."hello".."world".."hello".."hello".."world".."hello".."world"
  end
  print("string concat:",os.clock()-t2)
end

do
  local t1=os.clock()
  local str=""
  for i=1,10000 do
    str=str.."hello"
  end
  print(os.clock()-t1)
  local t2=os.clock()
  local str={}
  for i=1,10000 do
    table.insert(str,"hello")
  end
  str=table.concat(str)
  print(os.clock()-t2)
end
