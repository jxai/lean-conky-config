-- defend Lua version incompatibility, just in case
local _load = load
if _VERSION <= "Lua 5.1" then
    _load = loadstring
end

-- apply transform functions to rewrite values in a string
-- e.g. "$sc{42}" would be replaced by the value of T_sc(42)
function T_(s)
    local function _repl(f, args)
        return assert(_load("return T_" .. f .. "(" .. args .. ")"))()
    end

    return s:gsub("$([%w_]+){([^{}]*)}", _repl)
end

-- scale a number
function T_sc(num, scale)
    scale = scale or lcc.config.scale
    return num * scale
end

-- scale then round, for where only integers are allowed
function T_sr(num, scale)
    return math.floor(T_sc(num, scale) + 0.5)
end

-- scale then round to a multiple of 0.5
-- might be useful for certain cases, e.g. font size
function T_sh(num, scale)
    return math.floor(T_sc(num * 2, scale) + 0.5) / 2.0
end
