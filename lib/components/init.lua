local utils = require("utils")

local components = {}
C_ = components -- C_: global alias for `components`

-- core components
local core = require("components.core")
utils.table.update(components, core)

-- GPU support for different vendors, as of now only Nvidia's is supported
components.gpu = require("components.gpu")

function components.build_panel()
    local panel = {}
    for _, v in ipairs(lcc.panel) do
        if type(v) == "function" then v = v() end
        if v ~= nil then table.insert(panel, v) end
    end
    return T_(table.concat(panel, core.vspace(lcc.config.spacing)))
end

return components
