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
            table.insert(mnts, {
                mnt = mnt,
                type = type,
                size = tonumber(size),
                used = tonumber(used),
            })
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

-- pad string to `max_len`, `align` mode can be 'left', 'right' or 'center'
function padding(str, max_len, align, char)
    local n = max_len - utf8_len(str)
    if n <= 0 then return str end

    if not align then align = 'left' end
    if not char then char = ' ' end
    assert(utf8_len(char) == 1, 'padding `char` must be a single character.')

    local srep = string.rep
    if align == 'center' then
        local m = math.floor(n / 2)
        return srep(char, m) .. str .. srep(char, n - m)
    elseif align == 'left' then
        return str .. srep(char, n)
    elseif align == 'right' then
        return srep(char, n) .. str
    end
end

-- count characters in a utf-8 encoded string
function utf8_len(str)
    local _, count = string.gsub(str, '[^\128-\193]', '')
    return count
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
    padding = padding,
    percent_ratio = percent_ratio,
    stdout_lines = stdout_lines,
}