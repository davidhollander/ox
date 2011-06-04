
function subtest(msg)
  for i=1,#msg do
    if msg:sub(i-1,1)=='.' then
      return i
    end
  end
end

function findtest(msg)
  return msg:find('%.')
end

function bench(fn,n)
  local t = os.clock()
  for i=1,n do
    fn('lasdflkhsdafjkaohp sadofhjs aldkafsdlkh , asdflk. adsflksaf asfk')
  end
  print(os.clock()-t)
end
