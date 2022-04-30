-- defend Lua version incompatibility, just in case
local _load = load
if _VERSION <= "Lua 5.1" then
    _load = loadstring
end

local T_ = {}

-- scale a number
function T_.sc(num, scale)
    scale = scale or lcc.config.scale
    return num * scale
end

-- scale then round, for where only integers are allowed
function T_.sr(num, scale)
    return math.floor(T_.sc(num, scale) + 0.5)
end

-- scale then round to a multiple of 0.5
-- might be useful for certain cases, e.g. font size
function T_.sh(num, scale)
    return math.floor(T_.sc(num * 2, scale) + 0.5) / 2.0
end

-- apply transform functions to rewrite values in a string
-- e.g. "$sc{42}" would be replaced by the value of T_.sc(42)
setmetatable(T_, { __call = function(_, s)
    return s:gsub("$([%w_]+)(%b{})", function(f, args)
        return assert(_load("return T_." .. f .. "(" .. args:sub(2, -2) .. ")"))()
    end)
end })

return T_
