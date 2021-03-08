local _dirname_ = debug.getinfo(1, 'S').source:sub(2):match('(.*[/\\])')
package.path = _dirname_ .. '?.lua;' .. package.path
utils = require 'utils'

-- dynamically show active ifaces
-- see https://matthiaslee.com/dynamically-changing-conky-network-interface/
local TPL_IFACE =
[[${if_existing /sys/class/net/<IFACE>/operstate up}${voffset 2}${font :size=7}▼${font}  ${downspeed <IFACE>} ${alignc}${font :bold:size=8}<IFACE>${font} ${alignr}${upspeed <IFACE>} ${voffset -2}${font :size=7}▲
${font}${color lightgray}${downspeedgraph <IFACE> 32,130} ${alignr}${upspeedgraph <IFACE> 32,130 }$color${endif}]]

function conky_ifaces()
    local rendered = {}
    for i, iface in ipairs(utils.enum_ifaces()) do
        rendered[i] = TPL_IFACE:gsub('<IFACE>', iface)
    end
    if #rendered > 0 then
        return conky_parse(table.concat(rendered, '\n'))
    else
        return conky_parse("${font}(no active network interface found)")
    end
end

-- dynamically show mounted disks
local TPL_DISK =
[[${color}${font :bold:size=8}%s${font} ${alignc}%s / %s [%s] ${alignr}%s%%
${lua_bar 4 percent_ratio %s %s}$color]]

function conky_disks()
    local rendered = {}
    for i, disk in ipairs(utils.enum_disks()) do
        -- human friendly size strings
        local size_h = utils.filesize(disk.size)
        local used_h = utils.filesize(disk.used)

        -- get succinct name for the mount
        local name = disk.mnt
        local media = name:match('^/media/'..utils.env.USER..'/(.+)$')
        if media then
            name = media
        elseif name == utils.env.HOME then
            name = '${font :bold:size=11}⌂'
        end
        rendered[i] = string.format(TPL_DISK, name, used_h, size_h, disk.type,
                                    utils.percent_ratio(disk.used, disk.size),
                                    disk.used, disk.size)
    end
    if #rendered > 0 then
        return conky_parse(table.concat(rendered, '\n'))
    else
        return conky_parse("${font}(no mounted disk found)")
    end
end

-- unified shortcut to all top_x variables, with optional padding
function _top_val(ord, dev, type, max_len, align)
    if dev == 'io' or dev == 'mem' or dev == 'time' then
        dev = '_' .. dev
    else
        dev = ''
    end
    local rendered = conky_parse(
        string.format('${top%s %s %d}', dev, type, ord)
    )
    return utils.padding(utils.trim(rendered), max_len, align, ' ')
        -- NOTE: the padding character here is FIGURE SPACE (U+2007)
        -- see https://en.wikipedia.org/wiki/Whitespace_character
end

-- render top (cpu) line
function conky_top_cpu_line(ord)
    local _H = '${font :bold:size=8}PROCESS ${goto 156}PID ${goto 194}MEM% ${alignr}CPU%${font}'
    if ord == 'header' then return conky_parse(_H) end

    local function _t(type, padding_len)
        return _top_val(ord, 'cpu', type, padding_len, 'right')
    end
    return conky_parse(
        string.format('%s ${goto 156}%s ${goto 196}%s ${alignr}%s',
                      _t('name'), _t('pid'),
                      _t('mem', 6), _t('cpu'))
    )
end

-- render top_mem line
function conky_top_mem_line(ord)
    local _H = '${font :bold:size=8}PROCESS ${goto 156}PID ${goto 198}CPU%${alignr}MEM%${font}'
    if ord == 'header' then return conky_parse(_H) end

    local function _t(type, padding_len)
        return _top_val(ord, 'mem', type, padding_len, 'right')
    end
    return conky_parse(
        string.format('%s ${goto 156}%s ${goto 196}%s ${alignr}%s',
                      _t('name'), _t('pid'),
                      _t('cpu', 6), _t('mem'))
    )
end

-- render top_io line
function conky_top_io_line(ord)
    local _H = '${font :bold:size=8}PROCESS ${goto 156}PID ${alignr}READ/WRITE${font}'
    if ord == 'header' then return conky_parse(_H) end

    local function _t(type)
        return _top_val(ord, 'io', type)
    end
    return conky_parse(
        string.format('%s ${goto 156}%s ${alignr}%s / %s',
                      _t('name'), _t('pid'),
                      _t('io_read'), _t('io_write'))
    )
end

conky_percent_ratio = utils.percent_ratio
