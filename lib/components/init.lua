local utils = require("utils")

-- `lcc.tpl`: a template registry with lazy parsing
-- NOTE: lazy parsing (i.e. deferring template parsing till the first time it is
-- accessed) is crucial, otherwise configs such as `scale` might not have been
-- properly set up yet.
do
    local _tpl = utils.table.lazy()
    lcc.tpl = {
        -- a template including tforms applied to template variables, which have
        -- to be interpolated first, must be registered via this function. it is
        -- a bit less efficient than the regular __newindex version.
        dynamic_tform = function(name, text)
            _tpl:lazy(name, function()
                return function(args)
                    return T_(utils.tpl(text)(args))
                end
            end)
        end
    }
    setmetatable(lcc.tpl, {
        __newindex = function(_, name, text)
            _tpl:lazy(name, function()
                return utils.tpl(T_(text))
            end)
        end,
        __index = function(_, name)
            return _tpl[name]
        end
    })
end

local components = {}
C_ = components -- C_: global alias for `components`

------------------------
-- collect components --
------------------------
local core = require("components.core")
utils.table.update(components, core)

-- GPU support for different vendors, as of now only Nvidia's is supported
components.gpu = require("components.gpu")


------------------------
-- external interface --
------------------------
-- build the panel
function components.build_panel()
    local panel = {}
    for _, v in ipairs(lcc.panel) do
        if type(v) == "function" then v = v() end
        if v ~= nil then table.insert(panel, v) end
    end
    return table.concat(panel, core.vspace(lcc.config.spacing))
end

return components
