local _dir_ = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = _dir_ .. "../lib/?.lua;" .. _dir_ .. "../lib/?/init.lua;" .. package.path

_G.lcc = { root_dir = _dir_ .. "../" }
local utils = require("utils")

local pass, fail = 0, 0
local function test(name, actual, expected)
    if actual == expected then
        pass = pass + 1
    else
        fail = fail + 1
        print(string.format("FAIL: %s\n  expected: %s\n  actual:   %s",
            name, tostring(expected), tostring(actual)))
    end
end

local function test_range(name, actual, lo, hi)
    if type(actual) == "number" and actual >= lo and actual <= hi then
        pass = pass + 1
    else
        fail = fail + 1
        print(string.format("FAIL: %s\n  expected: %d..%d\n  actual:   %s",
            name, lo, hi, tostring(actual)))
    end
end

local spec  = "DejaVu Sans:size=12"
local spec2 = "DejaVu Sans:bold:size=16"
local spec3 = "DejaVu Sans Mono:size=10"

-----------------------------------------------
-- correctness
-----------------------------------------------
print("--- correctness ---")

test("nil returns 0",
    utils.text_width(nil, spec), 0)

test("empty string returns 0",
    utils.text_width("", spec), 0)

test("single char is positive",
    utils.text_width("A", spec) > 0, true)

test("known string 'Hello World' size=12",
    utils.text_width("Hello World", spec), 92)

test("known string 'Hello World' bold size=16",
    utils.text_width("Hello World", spec2), 146)

test("known string 'Hello World' mono size=10",
    utils.text_width("Hello World", spec3), 88)

-- longer string should be wider
local w_short = utils.text_width("Hi", spec)
local w_long  = utils.text_width("Hello World", spec)
test("longer string is wider",
    w_long > w_short, true)

-- bold/larger font should be wider
local w_reg  = utils.text_width("Hello", spec)
local w_bold = utils.text_width("Hello", spec2)
test("bold+larger font is wider",
    w_bold > w_reg, true)

-- monospace: width scales linearly with char count
local w1 = utils.text_width("A", spec3)
local w5 = utils.text_width("AAAAA", spec3)
test("monospace linear scaling",
    w5, w1 * 5)

-- same call returns same result (consistency)
local a = utils.text_width("test", spec)
local b = utils.text_width("test", spec)
test("repeated calls consistent", a, b)

-- matches single-shot subprocess (ground truth)
local script = _G.lcc.root_dir .. "lib/textwidth"
local out = utils.sys_call("'" .. script .. "' '" .. spec .. "' 'benchmark test'", true)
local expected_w = tonumber(out)
local actual_w = utils.text_width("benchmark test", spec)
test("matches single-shot subprocess",
    actual_w, expected_w)

-----------------------------------------------
-- serve process recovery
-----------------------------------------------
print("\n--- resilience ---")

-- after a valid call the process should be alive; a subsequent call should work
local w_before = utils.text_width("recovery", spec)
local w_after  = utils.text_width("recovery2", spec)
test("serve process stays alive across calls",
    type(w_after) == "number" and w_after > 0, true)

-----------------------------------------------
-- timing
-----------------------------------------------
print("\n--- timing ---")

-- prefer socket.gettime (wall-clock, microsecond resolution) over os.clock (CPU time)
local ok, socket = pcall(require, "socket")
local clock = ok and socket.gettime or os.clock
local clock_type = ok and "wall" or "cpu"
print("  (timer: " .. clock_type .. ")")

-- 1) first call (cold start: spawns process, resolves font)
local t0 = clock()
utils.text_width("cold_start_text", spec)
local dt_cold = clock() - t0
print(string.format("  cold start:           %.1f ms", dt_cold * 1000))
test_range("cold start < 500ms", dt_cold * 1000, 0, 500)

-- 2) pipe call (process warm, cache miss — measures via pipe round-trip)
-- use unique strings to avoid cache
t0 = clock()
local N_pipe = 20
for i = 1, N_pipe do
    utils.text_width("pipe_unique_" .. i, spec)
end
local dt_pipe = clock() - t0
local ms_per_pipe = dt_pipe / N_pipe * 1000
print(string.format("  pipe (warm, %d calls): %.1f ms total, %.2f ms/call", N_pipe, dt_pipe * 1000, ms_per_pipe))
test_range("pipe call < 5ms each", ms_per_pipe, 0, 5)

-- 3) cache hit (no pipe round-trip at all)
-- first populate cache
utils.text_width("cached_string", spec)
t0 = clock()
local N_cache = 10000
for i = 1, N_cache do
    utils.text_width("cached_string", spec)
end
local dt_cache = clock() - t0
local us_per_cache = dt_cache / N_cache * 1e6
print(string.format("  cache hit (%d calls):  %.2f ms total, %.3f us/call", N_cache, dt_cache * 1000, us_per_cache))
test_range("cache hit < 1us each", us_per_cache, 0, 1)

-- 4) single-shot subprocess baseline (for comparison)
t0 = clock()
local N_sub = 5
for i = 1, N_sub do
    local esc = ("subprocess_" .. i):gsub("'", "'\\''")
    utils.sys_call("'" .. script .. "' '" .. spec .. "' '" .. esc .. "'", true)
end
local dt_sub = clock() - t0
local ms_per_sub = dt_sub / N_sub * 1000
print(string.format("  subprocess (%d calls): %.1f ms total, %.1f ms/call", N_sub, dt_sub * 1000, ms_per_sub))

-- speedup
local speedup = ms_per_sub / ms_per_pipe
print(string.format("\n  => pipe speedup vs subprocess: %.0fx", speedup))
test_range("speedup > 10x", speedup, 10, 10000)

-----------------------------------------------
-- summary
-----------------------------------------------
print(string.format("\n%d passed, %d failed, %d total", pass, fail, pass + fail))
if fail > 0 then os.exit(1) end
