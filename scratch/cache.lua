--cache.lua
--An integrated asynchronous datastructure
--[[
    CacheGet('followers'..id,10,
        Get('rpc://data/followers',{user=id},
            function(data)
                if not data then CacheClear('user_info'..id)
                else CachePut('user_info'..id,r.user_info(data)) end end),
        function(cache)
            if not cache then NotFound()
            else res(cache,2) end end)
    CacheGet('actions'..client.user,10,
        Get('rpc://data/followers',{user=client.user},
            function(data)
                if not data then CacheClear('user_info'..id)
                else CachePut('actions'..client.user,r.user_actions(data)) end end),
        function(cache)
            if not cache then NotFound()
            else res(cache,3) end end) end]]
--local timeout=heap.new()
--Cache
local cache={}
local cache_expires={}
local cache_callbacks={}

module('ox.cache',package.seeall)
function CacheGet(key,f_update,f_cb)
    local x=cache_expires[key]
    if type(x)=='number' and x>os.time() or x then f_cb(cache[key])
    else
        f_update()
        table.insert(cache_callbacks[key],f_cb)
    end
end

function CachePut(key,time,value)
    cache[key]=value
    cache_expires[key]=type(time)=='number' and time+os.time() or time
    local cbs=cache_callbacks[key]
    if cbs then for i,cb in ipairs(cbs) do cb(value) end end
    cache_callbacks[key]={}
end

function CacheClear(key)
    local cbs=cache_callbacks[key]
    if cbs then for i,cb in ipairs(cbs) do cb(false) end end
    cache_callbacks[key]=nil
    cache_timestamp[key]=nil
    cache[key]=nil
end]]
