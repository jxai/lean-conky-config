-- utility functions and variables
local utils = {}

-- are we using Lua 5.1 (or below)
utils.lua_5_1 = (_VERSION <= "Lua 5.1")

-- shim functions
utils.loadstring = utils.lua_5_1 and loadstring or load

-- dump object
-- recursively dumps tables, with an optional depth limir (unlimited by default)
-- cf: https://stackoverflow.com/a/27028488/707516
function utils.dump_object(o, depth)
    if depth ~= nil and depth >= 0 then depth = depth - 1 end
    if type(o) == "table" then
        if depth < 0 then return "{...}" end
        local s = "{"
        local c = 0
        for k, v in pairs(o) do
            c = c + 1
            if type(k) ~= "number" then
                k = '"' .. k .. '"'
            end
            s = s .. " [" .. k .. "] = " .. utils.dump_object(v, depth) .. ","
        end
        if c > 0 then s = s:sub(1, -2) .. " " end
        return s .. "}"
    else
        local s = tostring(o)
        if type(o) == "string" then s = '"' .. s .. '"' end
        return s
    end
end

-- table utilities
utils.table = {
    unpack = utils.lua_5_1 and unpack or table.unpack
}

-- update `dst` table by merging the other `src` table
-- `overwrite`: if true (default), overwrite existing `dst` entries with values
-- from `src`, otherwise only merge those not already existing
function utils.table.update(dst, src, overwrite)
    if overwrite == nil then overwrite = true end
    if src then
        for k, v in pairs(src) do
            if overwrite or dst[k] == nil then
                dst[k] = v
            end
        end
    end
    return dst
end

-- get value with default
function utils.table.get(t, k, default)
    if t == nil then t = {} end
    local v = t[k]
    if v == nil then return default end
    return v
end

-- pop values from table (as multiple returns)
-- usage: local a, b = utils.table.pop({ x=1, y=2, z=3 }, 'x', 'z') -> a = 1, b = 3
function utils.table.pop(t, ...)
    if t == nil then t = {} end
    local ret = {}
    for _, k in ipairs(arg) do
        table.insert(ret, t[k])
        t[k] = nil
    end
    return utils.table.unpack(ret)
end

-- lazy table: storing values to be evaluated on the first access
-- usage:
--   local lz = utils.table.lazy()
--   local expensive_eval = function(t) return ... end -- argument `t` is optional
--   lz.foo = expensive_eval
function utils.table.lazy(vars)
    local lazy_t = require('external.lazybag').new()
    getmetatable(lazy_t).__newindex = function(t, k, v)
        t:lazy(k, v)
    end
    for k, v in pairs(vars or {}) do
        lazy_t[k] = v
    end
    return lazy_t
end

-- check if table `t` contains `val`
function utils.table.contains(t, val)
    if type(t) ~= "table" then return false end
    for _, v in ipairs(t) do
        if v == val then
            return true
        end
    end
    return false
end

-- load Lua file in a separate env to prevent polluting global env
function utils.load_in_env(path, env)
    local _env = env or {}
    if not env then
        setmetatable(_env, { __index = _G }) -- global fallback
    end

    if utils.lua_5_1 then
        local f = loadfile(path)
        if not f then return {} end
        assert(pcall(setfenv(f, _env)))
    else
        local f = loadfile(path, 't', _env)
        if not f then return {} end
        assert(pcall(f))
    end
    if not env then setmetatable(_env, nil) end
    return _env
end

-- enumerate network interfaces, see https://superuser.com/a/1173532/95569
function utils.enum_ifaces()
    local _in_docker = utils.in_docker()
    local ifaces = {}
    local iface_names = utils.sys_call("basename -a /sys/class/net/*")
    for i, l in ipairs(iface_names) do
        local p = utils.sys_call("realpath /sys/class/net/" .. l, true)
        -- for regular host, skip virtual interfaces (including lo)
        -- in container, return all interfaces except lo
        if not p:match("^/sys/devices/virtual/") or (_in_docker and l ~= "lo") then
            table.insert(ifaces, l)
        end
    end
    return ifaces
end

-- enumerate mounted disks
-- by default only show essential filesystems, but customizable
function utils.enum_disks(include_types, exclude_types, exclude_targets)
    local fs_types_default = "ext4,ext3,ext2,xfs,btrfs,zfs,ecryptfs,fuseblk,ntfs3,ntfs,vfat,exfat,fat"
    if utils.in_docker() then
        fs_types_default = fs_types_default .. ",overlay"
    end

    local fs_types = utils.clean_array(
        utils.str_to_array(fs_types_default .. "," .. include_types, ",", true, true),
        utils.str_to_array(exclude_types), true
    )

    local cmd = "findmnt -bPUno TARGET,FSTYPE,SIZE,USED -t " .. utils.join_strs(fs_types, ",")
    local entry_pattern = '^TARGET="(.+)"%s+FSTYPE="(.+)"%s+SIZE="(.+)"%s+USED="(.+)"$'
    local mnt_fs = utils.sys_call(cmd)
    local mnts = {}

    for _, l in ipairs(mnt_fs) do
        local mnt, type, size, used = l:match(entry_pattern)

        for _, p in ipairs(utils.str_to_array(exclude_targets) or {}) do
            if mnt == nil or mnt:match(p) then
                mnt = nil
                break
            end
        end
        if mnt and utils.is_dir(mnt) and utils.is_readable(mnt) then
            table.insert(mnts, {
                mnt = mnt,
                type = type,
                size = tonumber(size),
                used = tonumber(used)
            })
        end
    end
    return mnts
end

-- some environment variables
utils.env = {}
for i, k in ipairs({ "HOME", "USER" }) do
    utils.env[k] = os.getenv(k)
end

-- human friendly file size
local _filesize = require("external.filesize")
function utils.filesize(size)
    return _filesize(size, { round = 0, spacer = "", base = 2 })
end

-- call at interval, similar to Conky's `execi` but for functions
local _interval_call_cache = {}
local function _cache_key(func, ...)
    local key = tostring(func)
    for i = 1, select('#', ...) do key = key .. "\0" .. tostring(select(i, ...)) end
    return key
end
function utils.interval_call(interv, func, ...)
    local key = _cache_key(func, ...)
    if _interval_call_cache[key] == nil then
        _interval_call_cache[key] = {}
    end
    local cache = _interval_call_cache[key]
    local now = os.time()
    if cache.last == nil or (now - cache.last) >= interv then
        cache.result = func(...)
        cache.last = now
    end
    return cache.result
end

-- template renderer. usage:
--   foo_tpl = tpl("this is {%= foo %}")
--   foo_tpl{foo = "bar"} -> "this is bar"
local _liluat = require("external.liluat")
function utils.tpl(t)
    local ct = _liluat.compile(t, { start_tag = "{%", end_tag = "%}" })
    return function(values)
        return _liluat.render(ct, values)
    end
end

-- pad string to `max_len`, `align` mode can be 'l/left', 'r/right' or 'c/center'
function utils.padding(str, max_len, align, char)
    if not max_len then
        return str
    end
    local n = max_len - utils.utf8_len(str)
    if n <= 0 then
        return str
    end

    if not align then
        align = "l"
    end
    if not char then
        char = " "
    end
    assert(utils.utf8_len(char) == 1, "padding `char` must be a single character.")

    local srep = string.rep
    if align == "c" or align == "center" then
        local m = math.floor(n / 2)
        return srep(char, m) .. str .. srep(char, n - m)
    elseif align == "l" or align == "left" then
        return str .. srep(char, n)
    elseif align == "r" or align == "right" then
        return srep(char, n) .. str
    end
end

-- strip surrounding whitespaces
function utils.trim(str)
    return str:match("^%s*(.-)%s*$")
end

-- strip surrounding braces
function utils.unbrace(str)
    if not str then
        return str
    end
    while true do
        local u = str:match("^{(.-)}$")
        if u then
            str = u
        else
            return str
        end
    end
end

-- count characters in a utf-8 encoded string
function utils.utf8_len(str)
    local _, count = string.gsub(str, "[^\128-\193]", "")
    return count
end

-- split comma-separated string to array, supported separators are: ,(default) ; : - _ +
-- if str is already an array (table), it is returned without processing
-- if trim is true, surrounding spaces around each item are trimmed
-- if ignore_empty is true, only non-empty items (after optional trimming) are added
function utils.str_to_array(str, sep, trim, ignore_empty)
    if type(str) == "table" then return str end
    if type(str) ~= "string" then return nil end
    if sep == nil then sep = "," end
    if trim == nil then trim = false end
    if ignore_empty == nil then ignore_empty = false end

    if type(sep) ~= "string" or #sep ~= 1
        or not sep:match("[%,%;%:%-%_%+]") then
        return nil
    end
    local arr = {}
    local p = 1
    local function _append(s)
        if trim then s = utils.trim(s) end
        if #s > 0 or not ignore_empty then
            table.insert(arr, s)
        end
    end
    while true do
        local q = str:find(sep, p, true)
        if q then
            _append(string.sub(str, p, q - 1))
            p = q + 1
        else
            _append(string.sub(str, p))
            break
        end
    end
    return arr
end

-- clean array: exclude certain items and/or remove duplicate items
function utils.clean_array(arr, exclude, dedup)
    local exclude_hash = {}
    local dedup_hash = {}
    local cleaned = {}

    for _, k in ipairs(exclude) do
        exclude_hash[k] = true
    end

    for _, k in ipairs(arr) do
        if dedup and dedup_hash[k] or exclude_hash[k] then else
            table.insert(cleaned, k)
            if dedup then dedup_hash[k] = true end
        end
    end
    return cleaned
end

-- join strings stored in an array
function utils.join_strs(strs, sep)
    return table.concat(strs, sep)
end

-- round float to integer or specified number of digits
function utils.round(x, ndigits)
    ndigits = math.floor(ndigits or 0)
    if ndigits <= 0 then return math.floor(x + 0.5) end
    local pow = 10 ^ ndigits
    return math.floor(x * pow + 0.5) / pow
end

-- pow with fallback, see https://www.lua.org/manual/5.3/manual.html#8.2
utils.pow = math.pow or (function(a, b) return (a) ^ (b) end)

-- calculate ratio as percentage
function utils.ratio_perc(x, y, ndigits)
    return utils.round(100.0 * tonumber(x) / tonumber(y), ndigits)
end

-- run system command and return stdout as lines or a string
-- also return the exit code - or nil if execution fails or is interrupted (e.g. process killed)
-- if timeout (seconds) is given, kill cmd after that duration and return exit code 124
-- NOTE: timeout applies to the first token of cmd only; wrap complex commands in sh -c '...'
function utils.sys_call(cmd, as_string, timeout)
    local marker = "__EXIT_2cc9171556dd44b1aba0e283eca6a8ba="
    if timeout then cmd = "timeout " .. timeout .. " " .. cmd end
    local pipe = io.popen([[_OUTPUT=$(]] .. cmd ..
        [[); _RC=$?; printf '%s' "$_OUTPUT"; printf ']] .. marker .. [[%d' "$_RC"]])
    if not pipe then return end

    local lines = {}
    for l in pipe:lines() do
        table.insert(lines, l)
    end
    pipe:close()

    if #lines == 0 then return end
    local last_line, return_code = lines[#lines]:match("^(.*)" .. marker .. "(.*)$")
    if not last_line then return end -- execution interrupted

    lines[#lines] = last_line
    return_code = tonumber(return_code)

    if as_string then
        return table.concat(lines, "\n"), return_code
    else
        return lines, return_code
    end
end

-- JSON utilities
local _json = require("external.json")
utils.json = {
    loads = _json.decode,
    dumps = _json.encode,
}

-- fetch JSON data with curl and decode
-- NOTE: 10 seconds timeout by default
function utils.json.curl(url, timeout)
    timeout = timeout or 10
    local out, rc = utils.sys_call('curl --silent "' .. url .. '"', true, timeout)
    if not rc or rc > 0 or not out then return end
    local data = utils.json.loads(out)
    return data
end

-- eval string as system call and check if result is true
function utils.is_true(expr)
    local s = utils.sys_call(expr .. ' && echo "true"', true)
    return (#s > 3)
end

-- is dir or file
function utils.is_dir(p)
    return utils.is_true('[ -d "' .. p .. '" ]')
end

-- is path readable
function utils.is_readable(p)
    return utils.is_true('[ -r "' .. p .. '" ]')
end

-- is running in a docker container
function utils.in_docker()
    return utils.is_true('[ -f /.dockerenv ] || grep -Eq "(lxc|docker)" /proc/1/cgroup')
end

-- date/time utils
local _date = require("external.date")
-- returns seconds since the epoch at the datetime specified as a string
function utils.time_from_str(datetime)
    local d = _date(datetime):toutc() - _date.epoch()
    if d then return d:spanseconds() else return nil end
end

-- calculates rendered text width given a fontconfig pattern (with `size`/`pixelsize` specified)
-- uses a persistent textwidth process for performance (avoids per-call subprocess overhead);
-- results are cached by (font_spec, text) pair by default; pass `cache=false` to skip
local _lru = require("external.lru")
local _text_width_cache = _lru.new(1024)
local _tw_reader, _tw_writer -- persistent textwidth co-process

local function _tw_ensure()
    if _tw_reader then return true end
    ---@diagnostic disable-next-line: undefined-field
    local script = _G.lcc.root_dir .. "lib/textwidth"
    local fifo = os.tmpname()
    os.remove(fifo)
    if os.execute("mkfifo '" .. fifo .. "'") == nil then return false end
    -- start persistent process: reads from FIFO via stdin, writes widths to stdout
    _tw_reader = io.popen("'" .. script .. "' --serve < '" .. fifo .. "'", "r")
    -- opening the write end unblocks the reader (POSIX FIFO rendezvous)
    _tw_writer = io.open(fifo, "w")
    os.remove(fifo)
    if not _tw_writer or not _tw_reader then
        if _tw_writer then
            _tw_writer:close(); _tw_writer = nil
        end
        if _tw_reader then
            _tw_reader:close(); _tw_reader = nil
        end
        return false
    end
    return true
end

function utils.text_width(text, font_spec, cache)
    if not text or text == "" then return 0 end

    local cache_key = font_spec .. "\0" .. text
    if cache ~= false then
        local cached = _text_width_cache:get(cache_key)
        if cached then return cached end
    end

    local w
    if _tw_ensure() then
        _tw_writer:write(font_spec .. "\t" .. text .. "\n")
        _tw_writer:flush()
        local line = _tw_reader:read("*l")
        w = tonumber(line)
        if not w then
            -- process died; reset so next call retries
            _tw_reader:close(); _tw_writer:close()
            _tw_reader, _tw_writer = nil, nil
        end
    end

    if not w then
        -- fallback to single-shot subprocess
        ---@diagnostic disable-next-line: undefined-field
        local script = _G.lcc.root_dir .. "lib/textwidth"
        local esc = text:gsub("'", "'\\''")
        local out = utils.sys_call("'" .. script .. "' '" .. font_spec .. "' '" .. esc .. "'", true)
        w = tonumber(out)
    end

    if cache ~= false and w then _text_width_cache:set(cache_key, w) end
    return w
end

-- get detailed geocode info from lat and lon
function utils.reverse_geocode(lat, lon)
    local url = "api-bdc.io/data/reverse-geocode-client?latitude=" ..
        lat .. "&longitude=" .. lon .. "&localityLanguage=en"
    return utils.json.curl(url)
end

-- oscillating signal generator
function utils.oscillate(min, max, period, as_int, spiky)
    local t = os.time()
    -- sum of incommensurate sine waves for an irregular, non-repeating pattern
    local v = 0.5
        + 0.30 * math.sin(2 * math.pi * t / period)
        + 0.15 * math.sin(2 * math.pi * t / (period * 0.7 + 1))
        + 0.10 * math.sin(2 * math.pi * t / (period * 0.3 + 2))
    v = math.max(0, math.min(1, v))
    if spiky then v = utils.pow(v, 5) end
    v = min + (max - min) * v
    return as_int and utils.round(v) or v
end

-- conky "specials": variables that create entries in the global specials
-- linked list during parsing and emit SPECIAL_CHAR (\x01) markers in the output.
-- stripping them before conky_parse prevents side-effects on the specials list.
local _conky_specials = {
    -- color / font families
    "color%d?", "font%d?",
    -- positioning / alignment
    "goto", "alignr", "alignc", "offset", "voffset", "tab",
    -- lines
    "hr", "stippled_hr",
    -- background / outline
    "shadecolor", "outlinecolor",
    -- misc
    "save_coordinates",
    -- bar / gauge / graph (any variable ending with these suffixes)
    "[%w_]+bar", "[%w_]+gauge", "[%w_]+graph",
    -- irregularly named bar
    "cmus_progress",
}
-- build patterns that match ${special ...} or ${special} or $special
local _conky_special_patterns
do
    local pats = {}
    for _, s in ipairs(_conky_specials) do
        -- ${special args} or ${special} — word boundary after name prevents
        -- over-matching
        pats[#pats + 1] = "%${" .. s .. "%f[^%w_][^}]*}"
        pats[#pats + 1] = "%${" .. s .. "}"
        -- $special (bare, no braces) — ends at non-word char
        pats[#pats + 1] = "%$" .. s .. "%f[^%w_]"
    end
    _conky_special_patterns = pats
end
-- strip conky specials from an unparsed conky text string.
-- returns the cleaned text safe for conky_parse without polluting the global
-- specials list.
function utils.strip_specials(text)
    if not text then return text end
    for _, pat in ipairs(_conky_special_patterns) do
        text = text:gsub(pat, "")
    end
    return text
end

return utils
