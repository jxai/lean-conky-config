local utils = require("utils")
local core = {}

-------------------------------
-- conky interface functions --
-------------------------------
-- render `text` with the specified `font` if it is available on the system.
-- if `font ` unavailable, render `alt_text` instead with `alt_font`.
-- if `alt_font` is unavailable or not specified, render `alt_text` with the
-- current font.
-- if no `alt_text` is provided, it is assumed to be the same as `text`.
-- if no `text` is provided, it becomes a font-changing directive
-- `font` and `alt_font` may include property overrides after the font key,
-- e.g. "icon:size=24" or "icon:bold:size=24", which replace all original
-- font properties
function conky_font(font, text, alt_text, alt_font)
    text = text and utils.unbrace(text) or ""
    if alt_text == nil then
        alt_text = text
    else
        alt_text = utils.unbrace(alt_text)
    end

    local function _resolve_font(font_arg)
        if not font_arg then return nil end

        local p = font_arg:find(":", 1, true)
        local prop = nil
        if p then
            prop = font_arg:sub(p)
            font_arg = font_arg:sub(1, p - 1)
        end
        local res = lcc.fonts[font_arg]
        if res and prop then
            res = res:match("^([^:]+)") .. prop
        end
        return res
    end

    local font_res     = _resolve_font(font)
    local alt_font_res = _resolve_font(alt_font)
    if font_res then
        return conky_parse(string.format("${font %s}%s", font_res, text))
    elseif alt_font_res then
        return conky_parse(string.format("${font %s}%s", alt_font_res, alt_text))
    else
        return conky_parse(alt_text)
    end
end

-- padding
function conky_pad(text, max_len, align, char)
    text = utils.unbrace(text)
    return utils.padding(utils.trim(conky_parse(text)), max_len, align, char)
end

-- ratio as percentage
conky_ratio_perc = utils.ratio_perc

-- echo arguments
function conky_echo(...)
    return ...
end

-- wrapper of string.format
function conky_format(...)
    return string.format(...)
end

----------------
-- components --
----------------
-- section title
lcc.tpl.section = [[
${color1}${voffset $sr{-2}}${lua font icon {{%= icon %} ${voffset $sr{-1}}} {}}#
${lua font h1 {{%= title %}}} ${hr $sr{1}}${color}${voffset $sr{5}}]]
function core.section(title, icon)
    return lcc.tpl.section { title = title, icon = icon }
end

-- print message
local _message_color = {
    error = "${color #f33}",
    warn = "${color #ff3}",
    info = "${color #3f3}",
} -- TODO: to be added into named colors
function core.message(...)
    local arg = { ... }
    local level, text
    if #arg < 1 then return "" end
    if #arg < 2 then
        text = ...
    else
        level, text = ...
    end
    if level and level:sub(-1, -1) == '+' then
        level = level:sub(1, -2)
        text = "${lua font h2}[" .. level:upper() .. "]${color}${font} " .. text
    else
        text = "${font}" .. text
    end
    return (_message_color[level] or "${color}") .. text
end

-- vertical spacing: `dy` is the height (in pixels) before scaling
lcc.tpl.dynamic_tform('vspace', "\n${voffset $sr{{%= dy %}}}")
function core.vspace(dy)
    return lcc.tpl.vspace { dy = dy }
end

lcc.tpl.datetime = [[
${color0}${voffset $sr{2}}${lua font date ${time %b %-d}}${alignr}#
${lua font time ${time %H:%M}${voffset $sr{-35}} ${time %H:%M}${voffset $sr{-40}} time_alt}
${alignc}${lua font week ${time %^A}}
${alignc}${lua font year ${time %Y}}${color}
${voffset $sr{-8}}]]
function core.datetime()
    return lcc.tpl.datetime()
end

lcc.tpl.weather = [[
${lua weather {%= interv %} {{%= loc %}}}]]
function core.weather(args)
    return lcc.tpl.weather {
        interv = utils.table.get(args, 'interval', 900),
        loc = utils.table.get(args, 'location', "auto"),
    }
end

function conky_weather(interv, loc)
    -- `loc` might has spaces, has to be wrapped and then unbraced here
    loc = loc and utils.unbrace(loc) or "auto"
    return core._interval_call(interv, _weather_wttrin, loc)
end

lcc.tpl.weather_wttrin = [[${voffset $sr{-5}}${color}${lua font icon_s { } {}}${font}{%= wd.loc %}
${voffset $sr{10}}${lua font icon:size=$sr{30} {%= wd.icon[2] %} {%= wd.icon[1] %} icon_alt:size=$sr{30}}${voffset $sr{-3}}${offset $sr{3}}${lua font h1:size=$sr{20} {{%= wd.tempC %}℃}}${font}
${voffset $sr{10}}{%= wd.desc %}${voffset $sr{-87}}
{% for i, fc in ipairs(wd.fc) do +%}
${alignc {%= (3-i)*$sr{50} %}}${offset $sr{120}}${font}{%= fc.day %}
${voffset $sr{5}}${alignc {%= (3-i)*$sr{50} %}}${offset $sr{120}}${lua font icon_l  {%= fc.icon[2] %} {%= fc.icon[1] %} icon_l_alt}
${voffset $sr{-5}}${alignc {%= (3-i)*$sr{50} %}}${offset $sr{120}}${font}{%= fc.maxtempC %} / {%= fc.mintempC %}℃${voffset $sr{-71}}{% end %}
${voffset $sr{80}}]]
function _weather_wttrin(loc)
    -- Code definitions: https://www.worldweatheronline.com/weather-api/api/docs/weather-icons.aspx
    function _weather_icon(code)
        local icons = {
            ['113'] = { "☀", "", "" }, -- Clear/Sunny
            ['116'] = { "☁", "", "" }, -- Partly Cloudy
            ['119'] = { "☁", "", "" }, -- Cloudy
            ['122'] = { "☁", "", "" }, -- Overcast
            ['143'] = { "≡", "", "" }, -- Mist
            ['176'] = { "☔", "", "" }, -- Patchy rain nearby
            ['179'] = { "❄", "", "" }, -- Patchy snow nearby
            ['182'] = { "☔", "", "" }, -- Patchy sleet nearby
            ['185'] = { "☔", "", "" }, -- Patchy freezing drizzle nearby
            ['200'] = { "⚡", "", "" }, -- Thundery outbreaks in nearby
            ['227'] = { "❄", "", "" }, -- Blowing snow
            ['230'] = { "❄", "", "" }, -- Blizzard
            ['248'] = { "≡", "", "" }, -- Fog
            ['260'] = { "≡", "", "" }, -- Freezing fog
            ['263'] = { "☔", "", "" }, -- Patchy light drizzle
            ['266'] = { "☔", "", "" }, -- Light drizzle
            ['281'] = { "☔", "", "" }, -- Freezing drizzle
            ['284'] = { "☔", "", "" }, -- Heavy freezing drizzle
            ['293'] = { "☔", "", "" }, -- Patchy light rain
            ['296'] = { "☔", "", "" }, -- Light rain
            ['299'] = { "☔", "", "" }, -- Moderate rain at times
            ['302'] = { "☔", "", "" }, -- Moderate rain
            ['305'] = { "☔", "", "" }, -- Heavy rain at times
            ['308'] = { "☔", "", "" }, -- Heavy rain
            ['311'] = { "☔", "", "" }, -- Light freezing rain
            ['314'] = { "☔", "", "" }, -- Moderate or heavy freezing rain
            ['317'] = { "☔", "", "" }, -- Light sleet
            ['320'] = { "☔", "", "" }, -- Moderate or heavy sleet
            ['323'] = { "❄", "", "" }, -- Patchy light snow
            ['326'] = { "❄", "", "" }, -- Light snow
            ['329'] = { "❄", "", "" }, -- Patchy moderate snow
            ['332'] = { "❄", "", "" }, -- Moderate snow
            ['335'] = { "❄", "", "" }, -- Patchy heavy snow
            ['338'] = { "❄", "", "" }, -- Heavy snow
            ['350'] = { "❄", "", "" }, -- Ice pellets
            ['353'] = { "☔", "", "" }, -- Light rain shower
            ['356'] = { "☔", "", "" }, -- Moderate or heavy rain shower
            ['359'] = { "☔", "", "" }, -- Torrential rain shower
            ['362'] = { "☔", "", "" }, -- Light sleet showers
            ['365'] = { "☔", "", "" }, -- Moderate or heavy sleet showers
            ['368'] = { "❄", "", "" }, -- Light snow showers
            ['371'] = { "❄", "", "" }, -- Moderate or heavy snow showers
            ['374'] = { "☔", "", "" }, -- Light showers of ice pellets
            ['377'] = { "☔", "", "" }, -- Moderate or heavy showers of ice pellets
            ['386'] = { "⚡", "", "" }, -- Patchy light rain in area with thunder
            ['389'] = { "⚡", "", "" }, -- Moderate or heavy rain in area with thunder
            ['392'] = { "⚡", "", "" }, -- Patchy light snow in area with thunder
            ['395'] = { "⚡", "", "" }, -- Moderate or heavy snow in area with thunder
        }
        return utils.table.get(icons, code)
    end

    function _day_of_week(date)
        local t = utils.time_from_str(date)
        if t == nil then return "???" else return os.date("%a", t) end
    end

    if loc:lower() == "auto" then
        local d = utils.json.curl("ip-api.com/json") -- more accurate auto location
        if d then
            loc = utils.join_strs({ d.city, d.region, d.countryCode }, " ")
            -- loc = string.format("%f,%f", tonumber(d.lat), tonumber(d.lon)) -- not working if latlon not precise
        else
            loc = ""
        end
    end
    loc = loc:gsub("%s+", "+")

    local w = utils.json.curl("wttr.in/" .. loc .. "?format=j1")
    if w then
        local forecast = {}
        for i = 1, 3 do
            local fw = w.weather[i]
            local fc = fw.hourly[5] -- condition forecast at noon
            forecast[i] = {
                day = _day_of_week(fw.date),
                desc = fc.weatherDesc[1].value,
                code = fc.weatherCode,
                icon = _weather_icon(fc.weatherCode),
                maxtempC = fw.maxtempC,
                mintempC = fw.mintempC,
                maxtempF = fw.maxtempF,
                mintempF = fw.mintempF,
            }
        end
        local c = w.current_condition[1]
        local weather_data = {
            loc = w.nearest_area[1].areaName[1].value .. ", " .. w.nearest_area[1].region[1].value,
            desc = c.weatherDesc[1].value,
            code = c.weatherCode,
            icon = _weather_icon(c.weatherCode),
            tempC = c.temp_C,
            tempF = c.temp_F,
            hum = c.humidity,
            fc = forecast,
        }
        return lcc.tpl.weather_wttrin { wd = weather_data }
    else
        return "ERROR: Failed to fetch weather data"
    end
end

lcc.tpl.system = [[
${font}${sysname} ${kernel} ${alignr}${machine}
Host:${alignr}${nodename}
Uptime:${alignr}${uptime}
Processes:${alignr}${running_processes} / ${processes}]]
function core.system(args)
    return core.section("SYSTEM", "") .. "\n" .. lcc.tpl.system()
end

-- helper to generate conky text for top_x variables, with optional padding
local function _top_val_text(num, dev, type, padded_len, align)
    if dev == "io" or dev == "mem" or dev == "time" then
        dev = "_" .. dev
    else
        dev = ""
    end
    local s = string.format("${top%s %s %d}", dev, type, num)
    if padded_len and align then
        s = string.format("${lua pad {%s} %s %s %s}", s, padded_len, align, " ")
    else
        s = string.format("${lua pad {%s}}", s) -- just trim
    end
    return s
    -- NOTE: the padding character here is FIGURE SPACE (U+2007)
    -- see https://en.wikipedia.org/wiki/Whitespace_character
end

local function get_top_entries(max, dev, types, padded_len, align)
    if max == nil or max <= 0 then return nil end
    if max > 10 then max = 10 end

    local function _p(param, idx)
        if type(param) == "table" then return param[idx] end
        return param
    end

    local top_entries = {}
    for i = 1, max do
        local v = {}
        for j, t in ipairs(types) do
            v[t] = _top_val_text(i, dev, t, _p(padded_len, j), _p(align, j))
        end
        table.insert(top_entries, v)
    end
    return top_entries
end

lcc.tpl.cpu = [[
${font}${execi 3600 grep model /proc/cpuinfo | cut -d : -f2 | tail -1 | sed 's/\s//'} ${alignr} ${cpu cpu0}%
${color3}${cpugraph cpu0}${color}
{% if top_cpu_entries then %}
${color2}${lua font h2 {PROCESS ${goto $sr{156}}PID ${goto $sr{194}}MEM% ${alignr}CPU%}}${font}${color}#
{% for _, v in ipairs(top_cpu_entries) do +%}
{%= v.name %} ${goto $sr{156}}{%= v.pid %}${alignr}${offset $sr{-44}}{%= v.mem %}
${voffset $sr{-13}}${alignr}{%= v.cpu %}{% end %}{% end %}]]
function core.cpu(args)
    local top_n = utils.table.get(args, 'top_n', 5)
    return core.section("CPU", "") .. "\n" .. lcc.tpl.cpu {
        top_cpu_entries = get_top_entries(top_n, "cpu", { "name", "pid", "mem", "cpu" })
    }
end

lcc.tpl.memory = [[
${color2}${lua font h2 RAM}${font}${color} ${alignc $sr{-16}}${mem} / ${memmax} ${alignr}${memperc}%
${color3}${membar}${color}
${color2}${lua font h2 SWAP}${font}${color} ${alignc $sr{-16}}${swap} / ${swapmax} ${alignr}${swapperc}%
${color3}${swapbar}${color}
{% if top_mem_entries then %}
${color2}${lua font h2 {PROCESS ${goto $sr{156}}PID ${goto $sr{198}}CPU%${alignr}MEM%}}${font}${color}#
{% for _, v in ipairs(top_mem_entries) do +%}
{%= v.name %} ${goto $sr{156}}{%= v.pid %}${alignr}${offset $sr{-44}}{%= v.cpu %}
${voffset $sr{-13}}${alignr}{%= v.mem %}{% end %}{% end %}]]
function core.memory(args)
    local top_n = utils.table.get(args, 'top_n', 5)
    return core.section("MEMORY", "") .. "\n" .. lcc.tpl.memory {
        top_mem_entries = get_top_entries(top_n, "mem", { "name", "pid", "cpu", "mem" })
    }
end

lcc.tpl.storage = [[
${lua disks 5}
${voffset $sr{4}}${lua font icon_s {} {Read:}} ${font}${diskio_read} ${alignr}${lua font icon_s {} {Write: }}${font}${diskio_write}${lua font icon_s { } {}}
${color3}${diskiograph_read {%= lcc.half_graph_size %}} ${alignr}${diskiograph_write {%= lcc.half_graph_size %}}${color}
{% if top_io_entries then %}
${color2}${lua font h2 {PROCESS ${goto $sr{156}}PID ${alignr}READ/WRITE}}${font}${color}#
{% for _, v in ipairs(top_io_entries) do +%}
{%= v.name %} ${goto $sr{156}}{%= v.pid %} ${alignr}{%= v.io_read %} / {%= v.io_write %}{% end %}{% end %}]]
function core.storage(args)
    local top_n = utils.table.get(args, 'top_n', 5)
    return core.section("STORAGE", "") .. "\n" .. lcc.tpl.storage {
        top_io_entries = get_top_entries(top_n, "io", { "name", "pid", "io_read", "io_write" })
    }
end

-- dynamically show mounted disks
lcc.tpl.disks = [[
{% if disks then %}
{% for _, v in ipairs(disks) do %}
${lua font h2 {{%= v.name %}}}${font} ${alignc $sr{-8}}{%= v.used_h %} / {%= v.size_h %} [{%= v.type %}] ${alignr}{%= v.used_perc %}%
${color3}${lua_bar ratio_perc {%= v.used %} {%= v.size %}}${color}
{% end %}
{% else %}
${font}(no mounted disk found)
{% end %}]]
function conky_disks(interv)
    return core._interval_call(interv, function()
        local disks = {}
        for _, disk in ipairs(utils.enum_disks(
            lcc.config.storage_include_fs,
            lcc.config.storage_exclude_fs,
            lcc.config.storage_exclude_paths)) do
            -- get succinct name for the mount
            local name = disk.mnt
            local media = name:match("^/media/" .. utils.env.USER .. "/(.+)$")
            if media then
                name = media
            elseif name == utils.env.HOME then
                name = T_ "${lua font icon_s  ${voffset $sr{-4}}⌂ icon_alt}"
            end

            table.insert(disks, {
                name = name,
                type = disk.type,
                used = disk.used,
                size = disk.size,
                used_perc = utils.ratio_perc(disk.used, disk.size),
                -- human friendly size strings
                used_h = utils.filesize(disk.used),
                size_h = utils.filesize(disk.size),
            })
        end
        return utils.trim(lcc.tpl.disks { disks = disks })
    end)
end

lcc.tpl.network = [[
${color2}${lua font icon_s { } {}}${lua font h2 {Local IPs}}${alignr}${lua font h2 {External IP}}${lua font icon_s { } {}}${font}${color}
${execi 60 ip a | grep inet | grep -vw lo | grep -v inet6 | cut -d \/ -f1 | sed 's/[^0-9\.]*//g'}#
${alignr}${texeci 3600  wget -qO- https://checkip.amazonaws.com; echo}
${voffset $sr{5}}${lua ifaces 10}]]
function core.network()
    return core.section("NETWORK", "") .. "\n" .. lcc.tpl.network()
end

-- dynamically show active ifaces
-- see https://matthiaslee.com/dynamically-changing-conky-network-interface/
lcc.tpl.ifaces = [[
{% if ifaces then %}{% for _, iface in ipairs(ifaces) do %}
${if_existing /sys/class/net/{%= iface %}/operstate up}#
${lua font icon_s  ${voffset $sr{-1}}▼ icon_s_alt}${font}  ${downspeed {%= iface %}} ${alignc $sr{-22}}${lua font h2 {{%= iface %}}}${font}#
${alignr}${upspeed {%= iface %}}  ${lua font icon_s  ${voffset $sr{-2}}▲ icon_s_alt}${font}
${color3}${downspeedgraph {%= iface %} {%= lcc.half_graph_size %}} ${alignr}${upspeedgraph {%= iface %} {%= lcc.half_graph_size %} }${color}#
${endif}
{% end %}
{% else %}
${font}(no active network interface found)
{% end %}]]
function conky_ifaces(interv)
    return core._interval_call(interv, function()
        return utils.trim(lcc.tpl.ifaces { ifaces = utils.enum_ifaces() })
    end)
end

----------------------------
-- utils for internal use --
----------------------------
-- interval call
function core._interval_call(interv, ...)
    local ret = utils.interval_call(tonumber(interv or 0), ...)
    return ret and conky_parse(ret) or nil
end

return core
