-- vim: ft=lua:ts=4:sw=4:et:ai:cin
--
-- Demo mode: intercepts component output to replace Conky data variables
-- with mock values, while keeping all real templates and layout intact.
-- Zero template duplication — layout, icons, and formatting are identical
-- to normal mode.
-- Activated by setting `lcc.config.demo = true` in local.conf.

local utils = require("utils")

local demo = {}

----------------------------
-- dynamic value engine   --
----------------------------

local function oscillate(min, max, period, spiky)
    local t = os.time()
    -- sum of incommensurate sine waves for an irregular, non-repeating pattern
    local v = 0.5
        + 0.30 * math.sin(2 * math.pi * t / period)
        + 0.15 * math.sin(2 * math.pi * t / (period * 0.7 + 1))
        + 0.10 * math.sin(2 * math.pi * t / (period * 0.3 + 2))
    v = math.max(0, math.min(1, v))
    if spiky then
        -- push values toward 0 most of the time, only peaks break through
        v = v * v
        v = v * v
    end
    return min + (max - min) * v
end

local function oscillate_int(min, max, period, spiky)
    return math.floor(oscillate(min, max, period, spiky) + 0.5)
end

-- Conky calls this via ${lua demo_val <name>} or ${lua_graph "demo_val <name>"}
local _demo_vals        = {
    -- numeric values (for bars, graphs, percentages)
    cpu        = function() return oscillate_int(15, 85, 30) end,
    mem_perc   = function() return oscillate_int(40, 72, 60) end,
    swap_perc  = function() return oscillate_int(5, 25, 90) end,
    disk_read  = function() return oscillate_int(20, 1500, 20, true) end,
    disk_write = function() return oscillate_int(10, 800, 25, true) end,
    net_down   = function() return oscillate_int(5, 600, 15, true) end,
    net_up     = function() return oscillate_int(2, 150, 18, true) end,
}
-- formatted string values derived from the numeric values above (KiB -> bytes)
_demo_vals.disk_read_s  = function() return utils.filesize(_demo_vals.disk_read() * 1024) end
_demo_vals.disk_write_s = function() return utils.filesize(_demo_vals.disk_write() * 1024) end
_demo_vals.net_down_s   = function() return utils.filesize(_demo_vals.net_down() * 1024) end
_demo_vals.net_up_s     = function() return utils.filesize(_demo_vals.net_up() * 1024) end

-----------------
-- mock data   --
-----------------

-- minimal subset of WWO icons used by demo data (from weather.lua WWO_ICONS)
local DEMO_ICONS        = {
    sunny         = { "☀", "", "" }, -- WWO 113
    partly_cloudy = { "☁", "", "" }, -- WWO 116
    light_rain    = { "☔", "", "" }, -- WWO 296
}

local DEMO_WEATHER      = {
    loc = "London, England",
    desc = "Partly cloudy",
    icon = DEMO_ICONS.partly_cloudy,
    temp = "15℃",
    hum = "72",
    wind = "15 km/h",
    winddir = "SW",
    has_precip = false,
    precip = "0.0 mm",
    fc = {
        { day = "MON", icon = DEMO_ICONS.sunny, maxtemp = "17℃", mintemp = "10℃" },
        { day = "TUE", icon = DEMO_ICONS.light_rain, maxtemp = "13℃", mintemp = "8℃" },
        { day = "WED", icon = DEMO_ICONS.partly_cloudy, maxtemp = "15℃", mintemp = "9℃" },
    },
}

local DEMO_DISKS        = {
    {
        name = T_ "${lua font icon_s  ${voffset $sr{-4}}⌂ icon_alt}",
        type = "ext4",
        used = 180,
        size = 500,
        used_perc = "36",
        used_h = "180.0 GiB",
        size_h = "500.0 GiB",
    },
    {
        name = "Data",
        type = "ntfs",
        used = 750,
        size = 1024,
        used_perc = "73",
        used_h = "750.0 GiB",
        size_h = "1.0 TiB",
    },
}

local DEMO_IFACES       = { "eth0", "wlan0" }

local function mock_gpu(top_n)
    local g = {
        model_name = "NVIDIA GeForce RTX 4070",
        gpu_util = oscillate_int(20, 90, 25),
        gpu_temp = oscillate_int(45, 78, 40),
        gpu_temp_thres = 90,
        fan_speed = oscillate_int(30, 70, 35),
        power_usage = oscillate(80, 200, 30),
        power_limit = 250,
        mem_used = 4 * 1073741824,
        mem_total = 12 * 1073741824,
        mem_used_h = utils.filesize(4 * 1073741824),
        mem_total_h = utils.filesize(12 * 1073741824),
        mem_util = oscillate_int(25, 60, 50),
    }
    if top_n > 0 then
        g.processes = {}
        local names = { "python3", "Xorg", "firefox", "blender", "vlc" }
        local pids  = { "8891", "1204", "3842", "7123", "5567" }
        for i = 1, math.min(top_n, #names) do
            table.insert(g.processes, {
                name = names[i],
                pid = pids[i],
                gpu_mem = oscillate_int(100 * 1048576, 800 * 1048576, 20 + i * 10),
                gpu_util = oscillate(1, 30, 15 + i * 7),
            })
        end
    end
    return g
end

local DEMO_PROCS = {
    cpu_names = { "firefox", "code", "python3", "Xorg", "pulseaudio",
        "docker", "node", "java", "clang", "cargo" },
    cpu_pids  = { "3842", "5102", "8891", "1204", "2567",
        "6334", "7721", "4458", "9012", "3367" },
    mem_names = { "firefox", "code", "java", "docker", "python3",
        "node", "Xorg", "clang", "mysql", "redis" },
    mem_pids  = { "3842", "5102", "4458", "6334", "8891",
        "7721", "1204", "9012", "2233", "1156" },
    io_names  = { "firefox", "code", "docker", "mysql", "python3" },
    io_pids   = { "3842", "5102", "6334", "2233", "8891" },
}

-----------------------------------------------------
-- demoify: replace Conky data vars with mock values
-----------------------------------------------------
-- Applied to real component output via string replacement.
-- Layout/formatting vars (${color}, ${font}, ${alignr}, ${goto},
-- ${voffset}, ${hr}, ${offset}, etc.) pass through untouched,
-- guaranteeing identical layout to normal mode.

local function demoify(text)
    -- === datetime ===
    -- braces keep multi-word values as a single arg inside ${lua} calls
    text = text:gsub("%${time %%b %%%-d}", "{Jun 9}")
    text = text:gsub("%${time %%H:%%M}", "10:08")
    text = text:gsub("%${time %%^A}", "MONDAY")
    text = text:gsub("%${time %%Y}", "2025")

    -- === system ===
    text = text:gsub("%${sysname}", "Linux")
    text = text:gsub("%${kernel}", "6.8.0-100-generic")
    text = text:gsub("%${machine}", "x86_64")
    text = text:gsub("%${nodename}", "demo-host")
    text = text:gsub("%${uptime}", "42d 7h 15m")
    text = text:gsub("%${running_processes}", "342")
    text = text:gsub("%${processes}", "1024")

    -- === cpu ===
    text = text:gsub("%${execi 3600 grep model[^}]*}", "Intel Core i7-12700K")
    text = text:gsub("%${cpu cpu0}", "${lua demo_val cpu}")
    text = text:gsub("%${cpugraph cpu0}", '${lua_graph "demo_val cpu"}')

    -- === memory (longer names first to avoid partial match) ===
    text = text:gsub("%${memperc}", "${lua demo_val mem_perc}")
    text = text:gsub("%${memmax}", "16.0 GiB")
    text = text:gsub("%${membar}", "${lua_bar demo_val mem_perc}")
    text = text:gsub("%${mem}", "8.5 GiB")
    text = text:gsub("%${swapperc}", "${lua demo_val swap_perc}")
    text = text:gsub("%${swapmax}", "8.0 GiB")
    text = text:gsub("%${swapbar}", "${lua_bar demo_val swap_perc}")
    text = text:gsub("%${swap}", "1.2 GiB")

    -- === storage ===
    text = text:gsub("%${diskio_read}", "${lua demo_val disk_read_s}")
    text = text:gsub("%${diskio_write}", "${lua demo_val disk_write_s}")
    text = text:gsub("%${diskiograph_read ([^}]*)}", '${lua_graph "demo_val disk_read" %1}')
    text = text:gsub("%${diskiograph_write ([^}]*)}", '${lua_graph "demo_val disk_write" %1}')

    -- === network ===
    text = text:gsub("%${execi 60 ip[^}]*}", "192.168.1.100\n10.0.0.42")
    text = text:gsub("%${texeci [^}]*}", "203.0.113.42")
    -- ifaces: replace if_existing path so the guard always passes (demo ifaces may not exist)
    text = text:gsub("%${if_existing /sys/class/net/[^}]*}", "${if_existing /proc/uptime}")
    -- ifaces: replace speed vars (graph patterns before plain to avoid partial match)
    text = text:gsub("%${downspeedgraph (%S+ )([^}]*)}", '${lua_graph "demo_val net_down" %2}')
    text = text:gsub("%${upspeedgraph (%S+ )([^}]*)}", '${lua_graph "demo_val net_up" %2}')
    text = text:gsub("%${downspeed [^}]*}", "${lua demo_val net_down_s}")
    text = text:gsub("%${upspeed [^}]*}", "${lua demo_val net_up_s}")

    -- === top processes (name and pid by rank) ===
    for _, dev in ipairs({ "", "_mem", "_io" }) do
        local names = dev == "" and DEMO_PROCS.cpu_names
            or dev == "_mem" and DEMO_PROCS.mem_names
            or DEMO_PROCS.io_names
        local pids = dev == "" and DEMO_PROCS.cpu_pids
            or dev == "_mem" and DEMO_PROCS.mem_pids
            or DEMO_PROCS.io_pids
        text = text:gsub("%${top" .. dev .. " name (%d+)}", function(n)
            return names[tonumber(n)] or "process"
        end)
        text = text:gsub("%${top" .. dev .. " pid (%d+)}", function(n)
            return pids[tonumber(n)] or "0"
        end)
    end
    -- top value columns (dynamic per-process oscillating values)
    text = text:gsub("%${top cpu (%d+)}", function(n)
        return string.format("%.2f", oscillate(0.5, 15.0, 15 + tonumber(n) * 5))
    end)
    text = text:gsub("%${top mem (%d+)}", function(n)
        return string.format("%.2f", oscillate(0.5, 8.0, 20 + tonumber(n) * 7))
    end)
    text = text:gsub("%${top_mem cpu (%d+)}", function(n)
        return string.format("%.2f", oscillate(0.1, 5.0, 25 + tonumber(n) * 6))
    end)
    text = text:gsub("%${top_mem mem (%d+)}", function(n)
        return string.format("%.2f", oscillate(1.0, 12.0, 30 + tonumber(n) * 8))
    end)
    text = text:gsub("%${top_io io_read (%d+)}", function(n)
        return string.format("%.2f", oscillate(0, 500, 10 + tonumber(n) * 3))
    end)
    text = text:gsub("%${top_io io_write (%d+)}", function(n)
        return string.format("%.2f", oscillate(0, 300, 12 + tonumber(n) * 4))
    end)

    return text
end

--------------------------------------
-- conky_* function overrides       --
--------------------------------------
-- For components dispatched via ${lua func ...}, the C_ component
-- functions remain unchanged (they just emit ${lua ...} calls).
-- Only the conky_* backends are overridden to return mock data.
-- Templates are reused as-is; ifaces also goes through demoify
-- to strip ${if_existing} guards and replace speed variables.

function demo.conky_disks(_interv)
    return conky_parse(utils.trim(lcc.tpl.disks { disks = DEMO_DISKS }))
end

function demo.conky_ifaces(_interv)
    local text = utils.trim(lcc.tpl.ifaces { ifaces = DEMO_IFACES })
    return conky_parse(demoify(text))
end

function demo.conky_nvidia(_interv, top_n)
    top_n = tonumber(top_n or 0)
    local gpu_info = { mock_gpu(top_n) }
    return conky_parse(utils.trim(lcc.tpl.nvidia_nvml { gpu_info = gpu_info }))
end

function demo.conky_weather(_interv, _backend, _loc, _metric)
    return conky_parse(lcc.tpl.weather { wd = DEMO_WEATHER })
end

------------------
-- activation   --
------------------

function demo.activate()
    lcc.log.info("demo mode activated")

    -- global conky function for dynamic values in demo output
    _G.conky_demo_val = function(name)
        local fn = _demo_vals[name]
        return fn and tostring(fn()) or "0"
    end

    -- wrap real component functions: call real fn, then demoify its output
    for _, name in ipairs({ "datetime", "system", "cpu", "memory", "storage", "network" }) do
        local real_fn = C_[name]
        C_[name] = function(args) return demoify(real_fn(args)) end
    end

    -- override conky_* globals for Lua-dispatched components
    _G.conky_disks   = demo.conky_disks
    _G.conky_ifaces  = demo.conky_ifaces
    _G.conky_nvidia  = demo.conky_nvidia
    _G.conky_weather = demo.conky_weather
end

return demo
