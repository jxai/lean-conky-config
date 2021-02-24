function conky_ifaces()
    return conky_parse(render_ifaces(enum_ifaces()))
end

TPL_IFACE = 
[[${if_existing /sys/class/net/IFACE/operstate up}Down: ${downspeed IFACE}    ${alignc}${font :bold:size=8}IFACE${font} ${alignr}Up: ${upspeed IFACE} 
${color lightgray}${downspeedgraph IFACE 32,130} ${alignr}${upspeedgraph IFACE 32,130 }$color${endif}]]

function render_ifaces(ifaces)
    local rendered = {}
    for i, iface in ipairs(ifaces) do
        rendered[i] = TPL_IFACE:gsub('IFACE', iface)
    end
    return table.concat(rendered, '\n')
end

function enum_ifaces()
    local pipe = io.popen("basename -a /sys/class/net/*")
    local ifaces = {}
    for l in pipe:lines() do
        table.insert(ifaces, l)
    end
    pipe:close()
    return ifaces
end
