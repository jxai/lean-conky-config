-- defend Lua version incompatibility, just in case
local utils = require("utils")

local tform = {}
T_ = tform -- T_: global alias for `tform`

-- scale a number
function tform.sc(num, scale)
    scale = scale or lcc.config.scale
    return num * scale
end

-- scale then round, for where only integers are allowed
function tform.sr(num, scale)
    return math.floor(tform.sc(num, scale) + 0.5)
end

-- scale then round to a multiple of 0.5
-- might be useful for certain cases, e.g. font size
function tform.sh(num, scale)
    return math.floor(tform.sc(num * 2, scale) + 0.5) / 2.0
end

-- apply transform functions to rewrite values in a string
-- e.g. "$sc{42}" would be replaced by the value of T_.sc(42)
setmetatable(tform, { __call = function(_, s)
    local ts = s:gsub("$([%w_]+)(%b{})", function(f, args)
        return assert(utils.loadstring("return T_." .. f .. "(" .. args:sub(2, -2) .. ")"))()
    end)
    return ts
end })

return tform
