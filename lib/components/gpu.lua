local utils = require("utils")
local core = require("components.core")
local gpu = {}

-- conky built-in
lcc.tpl.nvidia_conky = [[
${font}${nvidia modelname 0} ${alignr} ${nvidia gpuutil 0}%
${color3}${nvidiagraph gpuutil 0}${color}
${color2}${lua font h2 FAN}${goto $sr{148}}${lua font h2 TEMP}${font}${color}${alignr}${offset $sr{-138}}${nvidia fanlevel 0}%
${voffset $sr{-13}}${alignr}${nvidia gputemp 0}℃
${color3}${nvidiabar {%= lcc.half_bar_size %} fanlevel 0}${color} ${alignr}${nvidiabar {%= lcc.half_bar_size %} gputemp 0}
${color2}${lua font h2 MEM}${font}${color} ${alignc $sr{-16}}${nvidia memused 0} MB / ${nvidia memmax 0} MB ${alignr}${nvidia membwutil 0}% ${color2}${lua font h2 UT}
${color3}${nvidiabar memutil 0}${color}]]
local function _nvidia_conky()
    return lcc.tpl.nvidia_conky()
end

-- more powerful, requires pynvml
lcc.tpl.nvidia_nvml = [[
{% for i, g in ipairs(gpu_info) do %}
${font}${color}{%= g.gpu_util %}%${alignc $sr{-16}}{%= g.model_name %}${alignr}{%= g.gpu_temp %}℃
${color3}${lua_graph "echo {%= g.gpu_util %}" {%= lcc.half_graph_size %}} ${alignr}${lua_graph "echo {%= g.gpu_temp %}" {%= lcc.half_graph_size %} {%= g.gpu_temp_thres %}}${color}
${color2}${lua font h2 FAN}${goto $sr{148}}${lua font h2 POWER}${font}${color}${alignr}${offset $sr{-138}}{%= g.fan_speed %}%
${voffset $sr{-13}}${alignr}${lua format %.1f {%= g.power_usage %}}W
${color3}${lua_bar {%= lcc.half_bar_size %} echo {%= g.fan_speed %}} ${color}${alignr}${lua_bar {%= lcc.half_bar_size %} ratio_perc {%= g.power_usage %} {%= g.power_limit %}}
${color2}${lua font h2 MEM}${font}${color} ${alignc $sr{-16}}{%= g.mem_used_h %} / {%= g.mem_total_h %} ${alignr}{%= g.mem_util %}% ${color2}${lua font h2 UT}
${color3}${lua_bar ratio_perc {%= g.mem_used %} {%= g.mem_total %}}${color}
{% if g.processes then %}
${color2}${lua font h2 {PROCESS ${goto $sr{156}}PID ${goto $sr{194}}MEM%${alignr}GPU%}}${font}${color}#
{% for _, p in ipairs(g.processes) do +%}
{%= p.name %} ${goto $sr{156}}{%= p.pid %}${alignr}${offset $sr{-44}}${lua ratio_perc {%= p.gpu_mem %} {%= g.mem_total %} 2}
${voffset $sr{-13}}${alignr}${lua format %.1f {%= p.gpu_util %}}{% end %}{% end %}
{% end %}]]
local function _nvidia_nvml(top_n)
    local out, rc = utils.sys_call(lcc.root_dir .. "/lib/components/gpu_nvml 2>/dev/null", true)
    if rc > 0 or not out then return end
    local ok, gpu_info = pcall(utils.loadstring("return " .. out))
    if not ok then return end

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

lcc.tpl.nvidia = [[${lua nvidia {%= interv %} {%= top_n %}}]]
function gpu.nvidia(args)
    local interv = utils.table.get(args, 'interv', 4)
    local top_n = utils.table.get(args, 'top_n', 5)
    return core.section("GPU", "") .. "\n" .. lcc.tpl.nvidia {
        interv = interv,
        top_n = top_n
    }
end

local function parse_amdgpu_top_output(output, top)
  local processes = {}

  local lines = {}
  -- Split the output into lines and discard the first three lines
  for line in output:gmatch("[^\r\n]+") do
      table.insert(lines, line)
  end
  local top_n = top or #lines

  for i = 3, top_n * 3, 3 do
      local line = lines[i]
      local process_name, pid, vram = line:match("(%S+)%s+%(%s+(%d+)%)%s*,.-%bVRAM%s+(%d+)%s+MiB")
      if process_name and pid and vram then
          -- Store the extracted information in a table
          table.insert(processes, {
              name = process_name,
              pid = tonumber(pid),
              gpu_mem = tonumber(vram),
              gpu_util = 0 -- for now there's no way for obtaining it

          })
      end
  end

  return processes
end

lcc.tpl.amd_gpu = [[
{% for _, g in ipairs(gpu_info) do %}
${font}${color}{%= g.gpu_util %}%${alignc $sr{-16}}{%= g.model_name %}${alignr}{%= g.gpu_temp %}℃
${color3}${lua_graph "echo {%= g.gpu_util %}" {%= lcc.half_graph_size %}} ${alignr}${lua_graph "echo {%= g.gpu_temp %}" {%= lcc.half_graph_size %} {%= g.gpu_temp_thres %}}${color}
${color2}${lua font h2 FAN}${goto $sr{148}}${lua font h2 POWER}${font}${color}${alignr}${offset $sr{-138}}{%= g.fan_util %}%
${voffset $sr{-13}}${alignr}${lua format %.1f {%= g.power_usage %}}W
${color3}${lua_bar {%= lcc.half_bar_size %} echo {%= g.fan_util %}} ${color}${alignr}${lua_bar {%= lcc.half_bar_size %} ratio_perc {%= g.power_usage %} {%= g.power_limit %}}
${color2}${lua font h2 MEM}${font}${color} ${alignc $sr{-16}}{%= g.mem_used_h %} / {%= g.mem_total_h %} ${alignr}{%= g.mem_util %} ${color2}${lua font h2 UT}
${color3}${lua_bar ratio_perc {%= g.mem_used %} {%= g.mem_total %}}${color}
{% if g.processes then %}
${color2}${lua font h2 {PROCESS ${goto $sr{156}}PID ${goto $sr{194}}MEM%${alignr}GPU%}}${font}${color}#
{% for _, p in ipairs(g.processes) do +%}
{%= p.name %} ${goto $sr{156}}{%= p.pid %}${alignr}${offset $sr{-44}}${lua ratio_perc {%= p.gpu_mem %} {%= g.mem_total %} 2}
${voffset $sr{-13}}${alignr}${lua format %.1f {%= p.gpu_util %}}{% end %}{% end %}
{% end %}
]]

local function _amd_gpu_info(top_n)
  local json = require('json')

  local function read_file(path)
      local file = io.open(path, "r")
      if file then
          local content = file:read("*a")
          file:close()
          return content
      end
      return nil
  end

  local function read_from_std(command)
    local handle = io.popen(command)
    local data = handle:read("*a")
    handle:close()
    if data then
        return data
    end

    return nil
  end

  local function get_gpu_busy_percent(card)
      local path = string.format("/sys/class/drm/card%s/device/gpu_busy_percent", card)
      local content = read_file(path)
      return content and tonumber(content) or 0
  end

  -- Detect available GPU cards
  local gpu_cards = {}
  for i = 0, 10 do  -- Assuming up to 10 cards; adjust as necessary
      local path = string.format("/sys/class/drm/card%s/device", i)
      local f = io.popen("ls " .. path .. " 2>/dev/null")
      if f:read("*a") ~= "" then
          table.insert(gpu_cards, tostring(i))
      end
      f:close()
  end

  local json_data = read_from_std("amdgpu_top -d -J")
  local processes_dump = read_from_std("amdgpu_top -p")

  local data = json.decode(json_data)
  if not data or not data[1] then return end

  local sensors = data[1].Sensors
  local power_cap = data[1]["Power Cap"]
  local vram = data[1]["VRAM"]
  local device_name = data[1].DeviceName
  local fan_max = 3800 --  temp hotfix before amdgpu_top gets an update
  if sensors["Fan Max"] and sensors["Fan Max"].value then
      fan_max = sensors["Fan Max"].value
  end

  local gpu_info = {}

  for _, card in ipairs(gpu_cards) do
      table.insert(gpu_info, {
          model_name = device_name or "AMD GPU",
          gpu_util = get_gpu_busy_percent(card),
          gpu_temp = sensors["Edge Temperature"].value,
          gpu_temp_thres = 100,  -- Assuming 100°C as threshold, adjust as needed
          fan_speed = sensors["Fan"].value,
          fan_util = string.format("%.2f", (sensors["Fan"].value / fan_max) * 100),
          power_usage = sensors["Average Power"].value,
          power_limit = power_cap.current,
          mem_used = vram["Total VRAM Usage"].value,
          mem_total = vram["Total VRAM"].value,
          mem_util = string.format("%.2f%%", (vram["Total VRAM Usage"].value / vram["Total VRAM"].value) * 100),
          processes = parse_amdgpu_top_output(processes_dump, top_n)
      })
  end

  for _, g in ipairs(gpu_info) do
    g.mem_used_h = utils.filesize(g.mem_used * 1024 * 1024)
    g.mem_total_h = utils.filesize(g.mem_total * 1024 * 1024)
  end

  return utils.trim(lcc.tpl.amd_gpu { gpu_info = gpu_info })
end

function conky_amd(interv, top_n)
  local rendered = core._interval_call(
      interv, _amd_gpu_info, tonumber(top_n or 0)
  )
  if rendered then return rendered end
end

lcc.tpl.amd = [[${lua amd {%= interv %} {%= top_n %}}]]
function gpu.amd(args)
  local interv = utils.table.get(args, 'interv', 4)
  local top_n = utils.table.get(args, 'top_n', 5)
  return core.section("GPU", "") .. "\n" .. lcc.tpl.amd {
      interv = interv,
      top_n = top_n
  }
end

return gpu
