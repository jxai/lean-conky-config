local utils = require("utils")

-- conky interface functions (global conky_* API)
require("conky_api")

-- `lcc.tpl`: a template registry with lazy parsing
-- NOTE: lazy parsing (i.e. deferring template parsing till the first time it is
-- accessed) is crucial, otherwise configs such as `scale` might not have been
-- properly set up yet.
do
    local _tpl = utils.table.lazy()

    -- make `lcc` and `conky` contexts available
    local function _add_ctx(args)
        args = args or {}
        args.lcc = _G.lcc
        args.conky = _G.conky
        return args
    end

    lcc.tpl = {
        -- a template including tforms applied to template variables, which have
        -- to be interpolated first, must be registered via this function. it is
        -- a bit less efficient than the regular __newindex version.
        dynamic_tform = function(name, text)
            local ctpl = utils.tpl(text)
            _tpl:lazy(name, function()
                return function(args)
                    return T_(ctpl(_add_ctx(args)))
                end
            end)
        end
    }
    setmetatable(lcc.tpl, {
        __newindex = function(_, name, text)
            _tpl:lazy(name, function()
                local ctpl = utils.tpl(T_(text))
                return function(args)
                    return ctpl(_add_ctx(args))
                end
            end)
        end,
        __index = function(_, name)
            return _tpl[name]
        end
    })
end

local components = {}
C_ = components -- C_: global alias for `components`

-- demo module, mounted on lcc for easy access from component modules
lcc.demo = require("components.demo")

-------------------------
-- register components --
-------------------------
-- core components, directly mounted for easy access
local core = require("components.core")
utils.table.update(components, core)
-- GPU: only NVIDIA is supported now
components.gpu = require("components.gpu")
-- weather: wttr.in backend
components.weather = require("components.weather")

------------------------
-- external interface --
------------------------
-- build LCC panel specified as an array, each element being a component
-- component can be defined as one of the following:
-- - {func, ...} -- function and arguments
-- - func  -- shortcut for { func }
-- where `func` can be a component function, or its name (string)
-- if `func` is a string, the leading "C_." can be omitted for convenience
function components.build_panel()
    local panel = {}
    for i, c in ipairs(lcc.panel) do
        local ok, s = pcall(function()
            local func, args
            local tc = type(c)
            if tc == "function" or tc == "string" then
                func = c
                args = {}
            elseif tc == "table" then
                func = table.remove(c, 1)
                args = c
            else
                error("invalid type: " .. tc)
            end
            local name = type(func) == "string" and func or tostring(func)
            if type(func) == "string" then
                if string.sub(name, 1, 3) == "C_." then
                    name = string.sub(name, 4)
                else
                    func = "C_." .. func
                end
                func = utils.loadstring("return " .. func)()
            end
            if not func then error("component function not found") end
            local note
            if utils.table.contains(lcc.config.demo, name) or lcc.config.demo == true then
                func = lcc.demo.activate(func)
                note = "(demo)"
            end
            lcc.log.debug("building component [" .. i .. "]:", name, note or args)
            return func(utils.table.unpack(args))
        end)
        if not ok then
            lcc.log.error("component [" .. i .. "] failed", s)
            s = core.message(
                "error+", "invalid component [" .. i .. "]:\n" .. string.gsub(s, ": ", ":\n")
            )
        end
        if s then table.insert(panel, s) end
    end
    local text = table.concat(panel, core.vspace(lcc.config.spacing))
    if lcc.config.debug == "prof" then
        text = text .. "${lua profile}"
    end
    return text
end

return components
