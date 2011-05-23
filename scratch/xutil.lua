--persistance helpers
makebuffer=function()
    local out={}
    return function(...)
        if arg then for x in ipairs(arg) do table.insert(out,x) end
        else return table.concat(out)
        end
    end
end
makecounter=function()
    local i=0
    return function(n)
        if n then i=i+n end
        return i
    end
end
function range(n)
    local i=0
    return function()
        i=i+1
        return i<=n and i or nil
    end
end
collect=function(iter)
    local out={}
    for x in iter do table.insert(out,x) end
    return out
end
--http helpers
r_status={
    [200]="HTTP/1.1 200 OK\r\n",
    [404]="HTTP/1.1 404 Not Found\r\n",
    [303] = "HTTP/1.1 303 See Other\r\n",
    [307] = "Temporary Redirect",
    [500] = "HTTP/1.1 500 Internal Server Error",
}
r_header=function(k,v) return table.concat{k,': ',v,'\r\n'} end
r_chunk=function(c) return table.concat{string.format('%x',#c),'\r\n',c,'\r\n'} end
