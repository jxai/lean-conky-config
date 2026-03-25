local utils = require("utils")
local core = require("components.core")
local gpu = {}

-- conky built-in NVIDIA backend
lcc.tpl.nvidia_conky = [[
${font}${nvidia modelname 0} ${alignr} ${nvidia gpuutil 0}%
${color3}${nvidiagraph gpuutil 0}${color}
${color2}${lua font h2 FAN}${goto $sr{148}}${lua font h2 TEMP}${font}${color}${alignr}${offset $sr{-138}}${nvidia fanlevel 0}%
${voffset $sr{-13}}${alignr}${nvidia gputemp 0}℃
${color3}${nvidiabar {%= lcc.half_bar_size %} fanlevel 0}${color} ${alignr}${nvidiabar {%= lcc.half_bar_size %} gputemp 0}
${color2}${lua font h2 MEM}${font}${color} ${alignc $sr{-16}}${nvidia memused 0} MB / ${nvidia memmax 0} MB ${alignr}${nvidia membwutil 0}% ${lua font icon_s  UT}
${color3}${nvidiabar memutil 0}${color}]]
local function _nvidia_conky()
    return lcc.tpl.nvidia_conky()
end

-- pynvml NVIDIA backend - much more powerful, Python or system pynvml package required
lcc.tpl.nvidia_nvml = [[
{% for i, g in ipairs(gpu_info) do %}{% if i>1 then %}${voffset $sr{8}}
{% end %}
${font}${color}{%= g.gpu_util %}%${alignc $sr{-16}}{% if #gpu_info>1 then %}{%= i %}: {% end %}{%= g.model_name %}${alignr}{%= g.gpu_temp %}℃
${color3}${lua_graph "echo {%= g.gpu_util %}" {%= lcc.half_graph_size %}} ${alignr}${lua_graph "echo {%= g.gpu_temp %}" {%= lcc.half_graph_size %}{% if g.gpu_temp>=(0.8*g.gpu_temp_thres) then %} #fb3 #f33 -t{% end %}}${color}
${color2}${lua font h2 FAN}${goto $sr{148}}${lua font h2 POWER}${font}${color}${alignr}${offset $sr{-138}}{%= g.fan_speed %}%
${voffset $sr{-13}}${alignr}${lua format %.1f {%= g.power_usage %}}W
${color3}${lua_bar {%= lcc.half_bar_size %} echo {%= g.fan_speed %}} ${color}${alignr}${lua_bar {%= lcc.half_bar_size %} ratio_perc {%= g.power_usage %} {%= g.power_limit %}}
${color2}${lua font h2 MEM}${font}${color} ${alignc $sr{-16}}{%= g.mem_used_h %} / {%= g.mem_total_h %} ${alignr}{%= g.mem_util %}% ${lua font icon_s  UT}
${color3}${lua_bar ratio_perc {%= g.mem_used %} {%= g.mem_total %}}${color}
{% if g.processes then %}{% local p,q=53,83 %}
${color2}${lua tab h2 l {PROCESS} l{%= p %}% {PID} r{%= q %}% {MEM%} r {GPU%}}${color}#
{% for _, proc in ipairs(g.processes) do +%}
${lua tab {} l {{%= proc.name %}} l{%= p %}% {{%= proc.pid %}} r{%= q %}% {${lua ratio_perc {%= proc.gpu_mem %} {%= g.mem_total %} 2}} r {${lua format %.1f {%= proc.gpu_util %}}}}#
{% end %}{% end %}
{% end %}]]
local function _nvidia_nvml(top_n)
    local out, rc = utils.sys_call(lcc.root_dir .. "/lib/components/gpu_nvml 2>/dev/null", true)
    if not rc or rc > 0 or not out then return end
    local ok, gpu_info = pcall(utils.loadstring("return " .. out))
    if not ok then
        lcc.log.warn("gpu_nvml output parse failed")
        return
    end

    for _, g in ipairs(gpu_info) do
        g.mem_used_h = utils.filesize(g.mem_used)
        g.mem_total_h = utils.filesize(g.mem_total)

        if top_n > 0 then
            local p = g.processes
            while #p > top_n do
                table.remove(p)
            end
        end
    end
    return utils.trim(lcc.tpl.nvidia_nvml { gpu_info = gpu_info })
end

local _lz = utils.table.lazy {
    -- check if conky was built with nvidia support
    built_with_nvidia = function()
        return (conky_parse("${nvidia modelname}") ~= "${nvidia}")
    end
}

-- NVIDIA GPU component implementation
function conky_nvidia(interv, top_n)
    local rendered = core._interval_call(
        interv, _nvidia_nvml, tonumber(top_n or 0)
    )
    if rendered then return rendered end

    if _lz.built_with_nvidia then
        return core._interval_call(interv, _nvidia_conky)
    end

    return conky_parse(core.message("error+",
        "\nFailed to load Nvidia, two options to enable:\n" ..
        "1. Python + pynvml (recommended)\n" ..
        "2. Conky built with nvidia support"
    ))
end

-- NVIDIA GPU component
lcc.tpl.nvidia = [[${lua nvidia {%= interv %} {%= top_n %}}]]
function gpu.nvidia(args)
    local interv = utils.table.get(args, 'interv', 4)
    local top_n = utils.table.get(args, 'top_n', 5)
    return core.section("GPU", "") .. "\n" .. lcc.tpl.nvidia {
        interv = interv,
        top_n = top_n
    }
end

lcc.demo.def(gpu.nvidia, { -- demo: mock GPU data with oscillating metrics
    conky_funcs = {
        nvidia = function(_interv, top_n)
            top_n       = tonumber(top_n or 0)
            local names = { "python3", "Xorg", "firefox", "blender", "vlc" }
            local pids  = { "44076", "2518", "7291", "71230", "5567" }
            local g     = {
                model_name = "NVIDIA GeForce RTX 4070",
                gpu_util = utils.oscillate(20, 90, 25, true),
                gpu_temp = utils.oscillate(45, 78, 40, true),
                gpu_temp_thres = 90,
                fan_speed = utils.oscillate(30, 70, 35, true),
                power_usage = utils.oscillate(80, 200, 30),
                power_limit = 250,
                mem_used = 4 * 1073741824,
                mem_total = 12 * 1073741824,
                mem_used_h = utils.filesize(4 * 1073741824),
                mem_total_h = utils.filesize(12 * 1073741824),
                mem_util = utils.oscillate(25, 60, 50, true),
            }
            if top_n > 0 then
                g.processes = {}
                local n = math.min(top_n, #names)
                local tw = n * (n + 1) / 2 -- sum of weights: n, n-1, ..., 1
                for i = 1, n do
                    local share = (n + 1 - i) / tw
                    table.insert(g.processes, {
                        name = names[i],
                        pid = pids[i],
                        gpu_mem = math.floor(g.mem_used * share),
                        gpu_util = g.gpu_util * share,
                    })
                end
            end
            local gpu_info = { g }
            return conky_parse(utils.trim(lcc.tpl.nvidia_nvml { gpu_info = gpu_info }))
        end,
    },
})

return gpu
