local utils = require("utils")
local core = {}

-------------------------------
-- conky interface functions --
-------------------------------
-- renders text with specified font and placement
-- `pla`: placement (position and alignment) formatted as '[l|c|r][<pos>]'
--        l/c/r indicates left/center/right alignment respectively, if not specified left is assumed
--        <pos> can be in pixel (scaled) from the left boundary of the rendering area or percentage
--        e,g, `33.3%`
--        if neither is provided, string is rendered inline with no specific placement
-- `text`: string to render
-- `font`: key of the desired font, e.g. "h1"
-- `alt_font`: alternative font if `font `is not found on the system, if neither found or both empty
--             the default font will be used
-- `alt_text`: alternative text to be rendered when `font` is unavailable - this offers flexibility
--             of displaying something different while handling a missing `font`. If `nil`, it is
--             assumed to be the same as `text`
-- NOTE: `font` and `alt_font` may include property overrides following the font key, e.g.
--       "icon:size=24" or "icon:bold:size=24", which replace all original font properties
function conky_text(pla, text, font, alt_font, alt_text)
    -- `align`: 'l' - left, 'c' = center, 'r' - right, nil - inline
    -- `pos`: absolute postion of the text in physical (scaled) pixels
    local function _parse_placement(pla)
        if not pla then return end
        local align, pos_str = pla:lower():match("^([lcr]?)([+-]?%d*%.?%d*%%?)$")
        if not align then return end

        if align == "" then align = nil end
        -- if position not specified, to align against whole width
        if pos_str == "" then
            if align == 'l' then
                pos_str = "0"
            elseif align == 'c' then
                pos_str = "50%"
            elseif align == 'r' then
                pos_str = "100%"
            else
                return
            end
        elseif align == "" then
            align = 'l'
        end
        local perc = tonumber(pos_str:match("^([%d%.]+)%%$"))
        if perc then return align, utils.round(perc / 100 * conky_window.text_width) end
        return align, tonumber(pos_str)
    end
    local align, pos = _parse_placement(pla)

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

    local function _render(_text, _font)
        if not _font then _font = lcc.fonts.default end
        local s = string.format("${font %s}%s", _font, _text)
        if align then
            local p = conky_window.text_start_x + pos
            local w = utils.text_width(_text, _font)
            if align == 'c' then
                p = p - utils.round(w / 2)
            elseif align == 'r' then
                p = p - w
            end
            s = string.format("${goto %d}", p) .. s
        end
        return conky_parse(s)
    end
    if font_res then
        return _render(text, font_res)
    elseif alt_font_res then
        return _render(alt_text, alt_font_res)
    else
        return _render(alt_text)
    end
end

-------------------------------------------------------------------------------
-- ! WARNING ! `conky_font`:
-- 1. it is now a thin wrapper of `conky_text`, which is preferred for text rendering
-- 2. the API will likely undergo an incompatible change with a future release
-------------------------------------------------------------------------------
function conky_font(font, text, alt_text, alt_font)
    return conky_text(nil, text, font, alt_font, alt_text)
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
${color2}${lua font icon_s { } {✧ } icon_s_alt}${lua font h2 {Local IPs}}${alignr}${lua font h2 {External IP}}${lua font icon_s { } { ✦} icon_s_alt}${font}${color}
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
