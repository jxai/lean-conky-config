local _dir_ = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
if not string.find(package.path, _dir_ .. "?.lua;", 1, true) then package.path = _dir_ .. "?.lua;" .. package.path end
local utils = require("utils")

-- load conky and lcc settings, lcc is then globally accessible
local conf = utils.load_in_env(conky_config)

-- remove unavailable fonts
local function _check_fonts()
    for k, _ in pairs(lcc.fonts) do
        local font = lcc.fonts[k]
        local p = font:find(":")
        if p then
            font = font:sub(1, p - 1)
        end
        font = utils.trim(font)
        if #font > 0 and font ~= "sans-serif" and font ~= "serif" and font ~= "courier" and font ~= "monospace" then
            local s = utils.sys_call('fc-list -f "%{family[0]}" "' .. font .. '"', true)
            if #s < 1 then
                lcc.fonts[k] = nil
            end
        elseif not p then
            lcc.fonts[k] = nil
        end
    end
end

_check_fonts()

-- render `text` with the specified `font` if it is available on the system.
-- if `font ` unavailable, render `alt_text` instead with `alt_font`.
-- if `alt_font` is unavailable or not specified, render `alt_text` with the
-- current font.
-- if no `alt_text` is provided, it is assumed to be the same as `text`.
function conky_font(font, text, alt_text, alt_font)
    text = utils.unbrace(text)
    if alt_text == nil then
        alt_text = text
    else
        alt_text = utils.unbrace(alt_text)
    end
    if font then
        font = lcc.fonts[font]
    end
    if alt_font then
        alt_font = lcc.fonts[alt_font]
    end
    if font then
        return conky_parse(string.format("${font %s}%s", font, text))
    elseif alt_font then
        return conky_parse(string.format("${font %s}%s", alt_font, alt_text))
    else
        return conky_parse(alt_text)
    end
end

conky_percent_ratio = utils.percent_ratio

-- unified shortcut to all top_x variables, with optional padding
function _top_val(ord, dev, type, max_len, align)
    if dev == "io" or dev == "mem" or dev == "time" then
        dev = "_" .. dev
    else
        dev = ""
    end
    local rendered = conky_parse(string.format("${top%s %s %d}", dev, type, ord))
    return utils.padding(utils.trim(rendered), max_len, align, " ")
    -- NOTE: the padding character here is FIGURE SPACE (U+2007)
    -- see https://en.wikipedia.org/wiki/Whitespace_character
end

-- render top (cpu) line
function conky_top_cpu_line(ord)
    local _H = T_ "${color2}${lua font h2 {PROCESS ${goto $sr{156}}PID ${goto $sr{194}}MEM% ${alignr}CPU%}}${font}${color}"
    if ord == "header" then
        return conky_parse(_H)
    end

    local function _t(type, padding_len)
        return _top_val(ord, "cpu", type, padding_len, "right")
    end

    return conky_parse(
        string.format(
            T_ "%s ${goto $sr{156}}%s${alignr}${offset $sr{-44}}%s\n${voffset $sr{-13}}${alignr}%s",
            _t("name"),
            _t("pid"),
            _t("mem"),
            _t("cpu")
        )
    )
end

-- render top_mem line
function conky_top_mem_line(ord)
    local _H = T_ "${color2}${lua font h2 {PROCESS ${goto $sr{156}}PID ${goto $sr{198}}CPU%${alignr}MEM%}}${font}${color}"
    if ord == "header" then
        return conky_parse(_H)
    end

    local function _t(type, padding_len)
        return _top_val(ord, "mem", type, padding_len, "right")
    end

    return conky_parse(
        string.format(
            T_ "%s ${goto $sr{156}}%s${alignr}${offset $sr{-44}}%s\n${voffset $sr{-13}}${alignr}%s",
            _t("name"),
            _t("pid"),
            _t("cpu"),
            _t("mem")
        )
    )
end

-- render top_io line
function conky_top_io_line(ord)
    local _H = T_ "${color2}${lua font h2 {PROCESS ${goto $sr{156}}PID ${alignr}READ/WRITE}}${font}${color}"
    if ord == "header" then
        return conky_parse(_H)
    end

    local function _t(type)
        return _top_val(ord, "io", type)
    end

    return conky_parse(
        string.format(T_ "%s ${goto $sr{156}}%s ${alignr}%s / %s", _t("name"), _t("pid"), _t("io_read"), _t("io_write"))
    )
end

local function _interval_call(interv, ...)
    return conky_parse(utils.interval_call(tonumber(interv or 0), ...))
end

-- dynamically show active ifaces
-- see https://matthiaslee.com/dynamically-changing-conky-network-interface/
local TPL_IFACE =
T_ [[${if_existing /sys/class/net/<IFACE>/operstate up}#
${lua font icon_s  ${voffset $sr{-1}}${font :size=$sc{7}}▼}${font}  ${downspeed <IFACE>} ${alignc $sr{-22}}${lua font h2 {<IFACE>}}${font}#
${alignr}${upspeed <IFACE>} ${lua font icon_s  ${voffset $sr{-2}}${font :size=$sc{7}}▲}${font}
${color3}${downspeedgraph <IFACE> $sr{32},$sr{130}} ${alignr}${upspeedgraph <IFACE> $sr{32},$sr{130} }${color}#
${endif}]]

local function _conky_ifaces()
    local rendered = {}
    for i, iface in ipairs(utils.enum_ifaces()) do
        rendered[i] = TPL_IFACE:gsub("<IFACE>", iface)
    end
    if #rendered > 0 then
        return table.concat(rendered, "\n")
    else
        return "${font}(no active network interface found)"
    end
end

function conky_ifaces(interv)
    return _interval_call(interv, _conky_ifaces)
end

-- dynamically show mounted disks
local TPL_DISK =
T_ [[${lua font h2 {%s}}${font} ${alignc $sr{-8}}%s / %s [%s] ${alignr}%s%%
${color3}${lua_bar $sr{4} percent_ratio %s %s}${color}]]

local function _conky_disks()
    local rendered = {}
    for i, disk in ipairs(utils.enum_disks()) do
        -- human friendly size strings
        local size_h = utils.filesize(disk.size)
        local used_h = utils.filesize(disk.used)

        -- get succinct name for the mount
        local name = disk.mnt
        local media = name:match("^/media/" .. utils.env.USER .. "/(.+)$")
        if media then
            name = media
        elseif name == utils.env.HOME then
            name = T_ "${lua font icon_s  ${voffset $sr{-4}}${font :bold:size=$sc{11}}⌂}"
        end
        rendered[i] = string.format(
            TPL_DISK,
            name,
            used_h,
            size_h,
            disk.type,
            utils.percent_ratio(disk.used, disk.size),
            disk.used,
            disk.size
        )
    end
    if #rendered > 0 then
        return table.concat(rendered, "\n")
    else
        return "${font}(no mounted disk found)"
    end
end

function conky_disks(interv)
    return _interval_call(interv, _conky_disks)
end
