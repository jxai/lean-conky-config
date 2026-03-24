local _dir_ = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = _dir_ .. "../lib/?.lua;" .. _dir_ .. "../lib/?/init.lua;" .. package.path

local utils = require("utils")

local pass, fail = 0, 0
local function test(name, input, expected)
    local actual = utils.strip_specials(input)
    if actual == expected then
        pass = pass + 1
    else
        fail = fail + 1
        print(string.format("FAIL: %s\n  input:    %q\n  expected: %q\n  actual:   %q",
            name, input, expected, actual))
    end
end

-- nil / empty
test("nil input", nil, nil)
test("empty string", "", "")

-- plain text (no variables) — unchanged
test("plain text", "hello world", "hello world")
test("plain with newlines", "line1\nline2", "line1\nline2")

-- non-special conky variables — preserved
test("cpu variable", "${cpu}", "${cpu}")
test("memperc variable", "${memperc}", "${memperc}")
test("uptime variable", "up: ${uptime}", "up: ${uptime}")
test("mixed values", "${cpu}% ${memperc}% ${fs_used /}", "${cpu}% ${memperc}% ${fs_used /}")

-- color specials
test("color braced", "${color red}hello${color}", "hello")
test("color bare", "$color hello", " hello")
test("color0-9", "${color3}text${color}", "text")
test("color with hex", "${color #ff0000}text${color}", "text")
test("color no arg", "${color}", "")

-- font specials
test("font braced", "${font Mono:size=10}text${font}", "text")
test("font bare", "$font text", " text")
test("font0-9", "${font3 Mono:size=12}text${font}", "text")

-- positioning specials
test("goto", "${goto 100}text", "text")
test("alignr", "${alignr}text", "text")
test("alignr with arg", "${alignr 10}text", "text")
test("alignc", "${alignc}text", "text")
test("offset", "${offset 5}text", "text")
test("voffset", "${voffset -13}text", "text")
test("tab", "${tab 60}text", "text")

-- line specials
test("hr", "${hr 2}", "")
test("stippled_hr", "${stippled_hr}", "")

-- background / outline specials
test("shadecolor", "${shadecolor black}text", "text")
test("outlinecolor", "${outlinecolor white}text", "text")
-- no ${outline} variable exists in conky; outlinecolor is the real one

-- bar / gauge / graph specials
test("cpubar", "${cpubar 10,100}", "")
test("membar", "${membar}", "")
test("cpugauge", "${cpugauge}", "")
test("cpugraph", "${cpugraph 40,200}", "")
test("nvidiabar", "${nvidiabar 6 fanlevel 0}", "")
test("lua_bar", "${lua_bar 6,200 echo 50}", "")
test("lua_graph", "${lua_graph echo 50 40,200}", "")
test("downspeedgraph", "${downspeedgraph eth0 40,200}", "")
-- cmus_progress is the only barval variable that doesn't end in "bar"
test("cmus_progress", "${cmus_progress 10,200}", "")

-- save_coordinates
test("save_coordinates", "${save_coordinates 0}text", "text")

-- complex real-world examples
test("gpu line from lean-conky-config",
    "${color2}${lua font h2 FAN}${goto 148}${lua font h2 TEMP}${font}${color}${alignr}${offset -138}fan_val",
    "${lua font h2 FAN}${lua font h2 TEMP}fan_val")

test("mixed specials and values",
    "${color red}CPU: ${cpu}%${color} ${goto 100}MEM: ${memperc}%${alignr}${membar 6,60}",
    "CPU: ${cpu}% MEM: ${memperc}%")

test("graph line",
    "${color3}${cpugraph 40,200}${color}",
    "")

-- should NOT strip variables that merely contain special-like substrings
-- no real conky variable starts with "color" that isn't a special,
-- but verify the pattern doesn't over-match longer names
test("color prefix not over-matched", "${colorful foo}", "${colorful foo}")
test("freq not stripped", "${freq 1}", "${freq 1}")

-- bare $ form edge cases
test("bare color end of string", "text$color", "text")
test("bare offset mid-string", "a$offset b", "a b")

-- dollar escape — not a special, should be preserved
test("dollar escape", "costs $$5", "costs $$5")

-- multiple specials in sequence
test("consecutive specials",
    "${color red}${font Mono:size=10}${goto 50}hello",
    "hello")

print(string.format("\n%d passed, %d failed, %d total", pass, fail, pass + fail))
if fail > 0 then os.exit(1) end
