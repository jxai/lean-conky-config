local utils = require("utils")

local core = {}

local tpl_section =
utils.tpl [[${color1}${voffset $sr{-2}}${lua font icon {{%= icon %} ${voffset $sr{-1}}} {}}#
${lua font h1 {{%= title %}}} ${hr $sr{1}}${color}${voffset $sr{5}}
]]
function core.section(icon, title)
    return tpl_section { icon = icon, title = title }
end

local tpl_voffset = utils.tpl [[${voffset $sr{{%= dy %}}}]]
function core.voffset(dy)
    return tpl_voffset { dy = dy }
end

local tpl_datetime =
utils.tpl [[${color0}${voffset $sr{2}}${lua font date ${time %b %-d}}${alignr}#
${lua font time ${time %H:%M}${voffset $sr{-35}} ${time %H:%M}${voffset $sr{-40}} time_alt}
${alignc}${lua font week ${time %^A}}
${alignc}${lua font year ${time %Y}}${color}
${voffset $sr{5}}]]
function core.datetime()
    return tpl_datetime()
end

local tpl_system =
utils.tpl [[${font}${sysname} ${kernel} ${alignr}${machine}
Host:${alignr}${nodename}
Uptime:${alignr}${uptime}
Processes:${alignr}${running_processes} / ${processes}
]]
function core.system()
    return core.section("", "SYSTEM") .. tpl_system()
end

local tpl_cpu =
utils.tpl [[${font}${execi 3600 grep model /proc/cpuinfo | cut -d : -f2 | tail -1 | sed 's/\s//'} ${alignr} ${cpu cpu0}%
${color3}${cpugraph cpu0 $sr{32},$sr{270}}${color}
${lua top_cpu_line header}
${lua top_cpu_line 1}
${lua top_cpu_line 2}
${lua top_cpu_line 3}
${lua top_cpu_line 4}
${lua top_cpu_line 5}
]]
function core.cpu()
    return core.section("", "CPU") .. tpl_cpu()
end

local tpl_memory =
utils.tpl [[${color2}${lua font h2 RAM}${font}${color} ${alignc $sr{-16}}${mem} / ${memmax} ${alignr}${memperc}%
${color3}${membar $sr{4}}${color}
${color2}${lua font h2 SWAP}${font}${color} ${alignc $sr{-16}}${swap} / ${swapmax} ${alignr}${swapperc}%
${color3}${swapbar $sr{4}}${color}
${lua top_mem_line header}
${lua top_mem_line 1}
${lua top_mem_line 2}
${lua top_mem_line 3}
${lua top_mem_line 4}
${lua top_mem_line 5}
]]
function core.memory()
    return core.section("", "MEMORY") .. tpl_memory()
end

local tpl_storage =
utils.tpl [[${lua disks 5}
${voffset $sr{4}}${lua font icon_s {} {Read:}} ${font}${diskio_read} ${alignr}${lua font icon_s {} {Write: }}${font}${diskio_write}${lua font icon_s { } {}}
${color3}${diskiograph_read $sr{32},$sr{130}} ${alignr}${diskiograph_write $sr{32},$sr{130}}${color}
${lua top_io_line header}
${lua top_io_line 1}
${lua top_io_line 2}
${lua top_io_line 3}
${lua top_io_line 4}
${lua top_io_line 5}
]]
function core.storage()
    return core.section("", "STORAGE") .. tpl_storage()
end

local tpl_network =
utils.tpl [[${color2}${lua font icon_s { } {}}${lua font h2 {Local IPs}}${alignr}${lua font h2 {External IP}}${lua font icon_s { } {}}${font}${color}
${execi 60 ip a | grep inet | grep -vw lo | grep -v inet6 | cut -d \/ -f1 | sed 's/[^0-9\.]*//g'}#
${alignr}${texeci 3600  wget -q -O- https://ipecho.net/plain; echo}
${voffset $sr{5}}${lua ifaces 10}
]]
function core.network()
    return core.section("", "NETWORK") .. tpl_network()
end

return core
