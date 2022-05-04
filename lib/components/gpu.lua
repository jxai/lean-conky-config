local utils = require("utils")
local core = require("components.core")

local gpu = {}

local tpl_nvidia =
utils.tpl [[${font}${nvidia modelname 0} ${alignr} ${nvidia gpuutil 0}%
${color3}${nvidiagraph gpuutil $sr{32},$sr{270} 0}${color}
${color2}${lua font h2 MEM}${font}${color} ${alignc $sr{-16}}${nvidia memused 0} MB / ${nvidia memmax 0} MB ${alignr}${nvidia memutil 0}%
${color3}${nvidiabar $sr{4} memutil 0}${color}
${color2}${lua font h2 TEMP}${goto $sr{148}}${lua font h2 FAN}${font}${color}${alignr}${offset $sr{-138}}${nvidia gputemp 0}℃
${voffset $sr{-13}}${alignr}${nvidia fanlevel 0}%
${color3}${nvidiabar $sr{4},$sr{130} gputemp 0} ${alignr}${nvidiabar $sr{4},$sr{130} fanlevel 0}${color}]]
function gpu.nvidia(args)
    local top_n = utils.table.get(args, 'top_n', 5)
    return core.section("GPU", "") .. "\n" .. tpl_nvidia {}
end

return gpu
