local function partial(f,...)
    local args=...
    return function(...)
        for i,a in ipairs(arg) do table.insert(args) end
        f(unpack(args))
    end
end


