-- defend Lua version incompatibility, just in case
local _load = load
if _VERSION <= "Lua 5.1" then
    _load = loadstring
end

-- apply transform functions to rewrite values in a string
-- e.g. "$sr{42}" would be replaced by the value of T_sr(42)
function T_(s)
    local function _repl(f, args)
        return assert(_load("return T_".. f .. "(" .. args .. ")"))()
    end
    return s:gsub("$([%w_]+){([^{}]*)}", _repl)
end

-- scale a number
function T_s(num, scale)
    scale = scale or lcc.config.scale
    return num * scale
end

-- scale then ceil
function T_sc(num, scale)
    return math.ceil(T_s(num, scale))
end

-- scale then floor
function T_sf(num, scale)
    return math.floor(T_s(num, scale))
end

-- scale then round
function T_sr(num, scale)
    return math.floor(T_s(num, scale)+0.5)
end
