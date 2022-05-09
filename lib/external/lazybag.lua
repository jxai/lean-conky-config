local _VERSION     = 'lazybag v1.0.0'
local _DESCRIPTION = 'Plain Lua tables with lazily-initialized field values.'
local _COPYRIGHT   = 'Copyright (C) 2011-2012 Daniele Alessandri'

local lazybag = {}

local mt_newindex = function(t, key, value)
    getmetatable(t).storage[key] = value
end

local mt_index = function(t, key)
    local mt = getmetatable(t)
    local storage, generators = mt.storage, mt.generators
    if storage[key] == nil and generators[key] ~= nil then
        storage[key], generators[key] = generators[key](t, key), nil
    end
    return storage[key]
end

local fn_lazy = function(t, key, fn)
    if type(fn) ~= 'function' then
        error('Function expected')
    end
    getmetatable(t).generators[key] = fn
    return fn
end

local fn_islazy = function(t, key)
    return getmetatable(t).generators[key] ~= nil
end

local fn_rename = function(t, old, new)
    local generators = getmetatable(t).generators
    if generators[old] ~= nil then
        generators[new], generators[old] = generators[old], nil
    elseif t[old] ~= nil then
        t[new], t[old] = t[old], nil
    end
end

local fn_getraw = function(t, key)
    local mt = getmetatable(t)
    return mt.generators[key] or mt.storage[key]
end

lazybag.new = function(other)
    if other == lazybag then
        error('Cannot initialize a lazybag container with lazybag itself')
    end

    local t = {
        lazy = fn_lazy,
        islazy = fn_islazy,
        rename = fn_rename,
        getraw = fn_getraw,
    }

    if other ~= nil then
        for k, v in pairs(other) do
            if t[k] == nil then
                t[k] = v
            end
        end
    end

    local mt = {
        generators = {},
        storage = {},
        __index = mt_index,
        __newindex = mt_newindex,
    }

    return setmetatable(t, mt)
end

return lazybag
