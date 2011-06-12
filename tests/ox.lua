files={'core_test.lua','http_test.lua','file_test.lua'}
for i,v in ipairs(files) do
  print(i,'\t',v)
  dofile(v)
end
print('pass.')
