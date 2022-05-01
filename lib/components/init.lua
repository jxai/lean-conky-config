local components = {}
C_ = components -- C_: global alias for `components`

local utils = require("utils")
local core = require("components.core")
utils.update_table(components, core)

function components.build_panel()
    return T_(table.concat(lcc.panel, core.vspace(lcc.config.spacing)))
end

return components
