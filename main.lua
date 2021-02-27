local _filesize = require 'filesize'
function filesize(size)
    return _filesize(size, {round=0, spacer='', base=2})
end

function conky_ifaces()
    return conky_parse(render_ifaces(enum_ifaces()))
end

TPL_IFACE = 
[[${if_existing /sys/class/net/<IFACE>/operstate up}Down: ${downspeed <IFACE>}    ${alignc}${font :bold:size=8}<IFACE>${font} ${alignr}Up: ${upspeed <IFACE>}
${color lightgray}${downspeedgraph <IFACE> 32,130} ${alignr}${upspeedgraph <IFACE> 32,130 }$color${endif}]]

function render_ifaces(ifaces)
    local rendered = {}
    for i, iface in ipairs(ifaces) do
        rendered[i] = TPL_IFACE:gsub('<IFACE>', iface)
    end
    return table.concat(rendered, '\n')
end

-- enumerate all network interfaces
function enum_ifaces()
    return stdout_lines('basename -a /sys/class/net/*')
end

function stdout_lines(cmd)
    local pipe = io.popen(cmd)
    local lines = {}
    for l in pipe:lines() do
        table.insert(lines, l)
    end
    pipe:close()
    return lines
end

function conky_disks()
    return conky_parse(render_disks(enum_disks()))
end

-- enumerate all relevant mounted points
function enum_disks()
    local mnt_fs = stdout_lines('findmnt -bPUno TARGET,FSTYPE,SIZE,USED -t fuseblk,ext2,ext3,ext4,ecryptfs,vfat')
    local mnts = {}
    for i, l in ipairs(mnt_fs) do
        mnt, type, size, used = l:match('^TARGET="(.+)"%s+FSTYPE="(.+)"%s+SIZE="(.+)"%s+USED="(.+)"$')
        if mnt and not mnt:match('^/boot/') then
            table.insert(mnts, {mnt, type, tonumber(size), tonumber(used)})
        end
    end
    return mnts
end

TPL_DISK =
[[${color}${font :bold:size=8}%s${font} ${alignc}%s / %s [%s] ${alignr}%s
${lua_bar 5 perc %s %s}$color]]

function render_disks(disks)
    local rendered = {}
    for i, mnt in ipairs(disks) do
        mnt, type, size, used = unpack(mnt)
        size_h = filesize(size) -- human readable size format
        used_h = filesize(used)
        rendered[i] = string.format(TPL_DISK, mnt, used_h, size_h, type, conky_perc(used, size), used, size)
    end
    return table.concat(rendered, '\n')
end

function conky_perc(x, y)
    return math.floor(100.0 * tonumber(x) / tonumber(y))
end