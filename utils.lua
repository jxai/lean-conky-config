-- utility functions and variables

-- enumerate network interfaces, see https://superuser.com/a/1173532/95569
function enum_ifaces()
    return stdout_lines('basename -a /sys/class/net/*')
end

-- enumerate mounted disks
-- NOTE: only list most relevant mounts, e.g. boot partitions are ignored
function enum_disks()
    local cmd = 'findmnt -bPUno TARGET,FSTYPE,SIZE,USED -t fuseblk,ext2,ext3,ext4,ecryptfs,vfat'
    local mnt_fs = stdout_lines(cmd)
    local mnts = {}

    for i, l in ipairs(mnt_fs) do
        local mnt, type, size, used = l:match('^TARGET="(.+)"%s+FSTYPE="(.+)"%s+SIZE="(.+)"%s+USED="(.+)"$')
        if mnt and not mnt:match('^/boot/') then
            table.insert(mnts, {mnt, type, tonumber(size), tonumber(used)})
        end
    end
    return mnts
end

-- some environment variables
local env = {}
for i, k in ipairs({'HOME', 'USER'}) do
    env[k] = os.getenv(k)
end

-- human friendly file size
local _filesize = require 'filesize'
function filesize(size)
    return _filesize(size, {round=0, spacer='', base=2})
end

-- calculate ratio as percentage
function percent_ratio(x, y)
    return math.floor(100.0 * tonumber(x) / tonumber(y))
end

-- run command and return stdout lines
function stdout_lines(cmd)
    local pipe = io.popen(cmd)
    local lines = {}
    for l in pipe:lines() do
        table.insert(lines, l)
    end
    pipe:close()
    return lines
end


return {
    enum_ifaces = enum_ifaces,
    enum_disks = enum_disks,
    env = env,
    filesize = filesize,
    percent_ratio = percent_ratio,
    stdout_lines = stdout_lines,
}