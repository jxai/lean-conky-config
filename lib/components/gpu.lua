local utils = require("utils")
local core = require("components.core")

local gpu = {}

local tpl_nvidia_conky =
utils.tpl [[${font}${nvidia modelname 0} ${alignr} ${nvidia gpuutil 0}%
${color3}${nvidiagraph gpuutil $sr{32},$sr{270} 0}${color}
${color2}${lua font h2 MEM}${font}${color} ${alignc $sr{-16}}${nvidia memused 0} MB / ${nvidia memmax 0} MB ${alignr}${nvidia memutil 0}%
${color3}${nvidiabar $sr{4} memutil 0}${color}
${color2}${lua font h2 TEMP}${goto $sr{148}}${lua font h2 FAN}${font}${color}${alignr}${offset $sr{-138}}${nvidia gputemp 0}℃
${voffset $sr{-13}}${alignr}${nvidia fanlevel 0}%
${color3}${nvidiabar $sr{4},$sr{130} gputemp 0} ${alignr}${nvidiabar $sr{4},$sr{130} fanlevel 0}${color}]]
local function _nvidia_conky()
    return T_(tpl_nvidia_conky {})
end

local _nvidia_enabled = nil
function conky_nvidia(interv)
    -- check if conky was built with nvidia support
    if _nvidia_enabled == nil then
        _nvidia_enabled = (conky_parse("${nvidia modelname}") ~= "${nvidia}")
    end
    if _nvidia_enabled then
        return core._interval_call(interv, function()
            return _nvidia_conky()
        end)
    else
        return conky_parse(core.message("error+", "Conky not built with nvidia support"))
    end
end

function gpu.nvidia(args)
    return core.section("GPU", "") .. "\n" .. [[${lua nvidia 5}]]
end

return gpu
