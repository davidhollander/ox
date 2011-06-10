files={'core.lua','http.lua','file.lua'}
for i,v in ipairs(files) do
  print(i,'\t',v)
  dofile(v)
end
print('\t','pass.')
