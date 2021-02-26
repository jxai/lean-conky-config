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
    local mnt_fs = stdout_lines('findmnt -lno TARGET,FSTYPE')
    local mnts = {}
    for i, l in ipairs(mnt_fs) do
        for j, fs in ipairs({'fuseblk', 'ext[2-4]', 'ecryptfs', 'vfat'}) do
            s = l:match('^(.-)%s*'..fs..'$')
            if s and not s:match('^/boot/') then
                table.insert(mnts, s)
            end
        end
    end
    return mnts
end

TPL_DISK =
[[${if_mounted <MNT>}${color}${font :bold:size=8}<MNT>${font} ${alignc}${fs_used <MNT>} / ${fs_size <MNT>} [${fs_type <MNT>}] ${alignr}${fs_used_perc <MNT>}%
${fs_bar 5 <MNT>}$color${endif}]]

function render_disks(disks)
    local rendered = {}
    for i, mnt in ipairs(disks) do
        rendered[i] = TPL_DISK:gsub('<MNT>', mnt)
    end
    return table.concat(rendered, '\n')
end
