local fs=require'ox.fs'

print 'gdir'

do
  io.open('ox_fs_test1.one','w'):close()
  io.open('ox_fs_test2.one','w'):close()
  io.open('ox_fs_test3.two','w'):close()
end

do
  local a = 0
  for i in fs.gdir '?' do a = a+1 end
  local b = 0
  for i in fs.gdir '?.one' do
    b=b+1
    local f = assert(io.open(i))
    f:close()
  end
  local c=0
  for i in fs.gdir '?.two' do c=c+1 end
  assert(a>b and b>c)
end

print 'dir'

do
  local a = 0
  local ai = 0
  local b = 0
  local bi = 0
  for i in fs.dir() do
    a=a+1
    if i:match 'ox_fs_test' then ai=ai+1 end
  end
  for i in fs.dir '.' do
    b=b+1
    if i:match 'ox_fs_test' then bi=bi+1 end
  end
  assert(a==b and ai==bi and a>=5 and ai>=3)
end

os.execute 'rm ox_fs_test*'

print 'pass.'
