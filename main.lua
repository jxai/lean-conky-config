utils = require 'utils'

-- dynamically show active ifaces
-- see https://matthiaslee.com/dynamically-changing-conky-network-interface/
TPL_IFACE = 
[[${if_existing /sys/class/net/<IFACE>/operstate up}Down: ${downspeed <IFACE>}    ${alignc}${font :bold:size=8}<IFACE>${font} ${alignr}Up: ${upspeed <IFACE>}
${color lightgray}${downspeedgraph <IFACE> 32,130} ${alignr}${upspeedgraph <IFACE> 32,130 }$color${endif}]]

function conky_ifaces()
    local rendered = {}
    for i, iface in ipairs(utils.enum_ifaces()) do
        rendered[i] = TPL_IFACE:gsub('<IFACE>', iface)
    end
    return conky_parse(table.concat(rendered, '\n'))
end

-- dynamically show mounted disks
TPL_DISK =
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
        elseif mnt == utils.env.HOME then
            name = '${font :bold:size=11}⌂'
        end
        rendered[i] = string.format(TPL_DISK, name, used_h, size_h, disk.type,
                                    utils.percent_ratio(disk.used, disk.size),
                                    disk.used, disk.size)
    end
    return conky_parse(table.concat(rendered, '\n'))
end

-- render top_io line
function conky_top_io_line(ord)
    function _top_io(type)
        local rendered = conky_parse(
            string.format('${top_io %s %d}', type, ord)
        )
        return rendered:match( "^%s*(.-)%s*$" )
    end
    local rw = string.format('%s / %s', _top_io('io_read'), _top_io('io_write'))
    return conky_parse('${font DejaVu Sans Mono::size=8}'
                       .. _top_io('name')
                       .. ' ${alignr}' .. _top_io('pid')
                       .. utils.padding(rw, 15, 'right', ' '))
end

conky_percent_ratio = utils.percent_ratio