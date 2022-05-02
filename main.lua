local _dir_ = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
if not string.find(package.path, _dir_ .. "lib/?.lua;", 1, true) then
    package.path = _dir_ .. "lib/?.lua;" .. _dir_ .. "lib/?/init.lua;" .. package.path
end
local utils = require("utils")

-- load conky and lcc settings, lcc is globally accessible
local conf = utils.load_in_env(conky_config)
-- global functions defined in the required packages (components, tform) are
-- also available now
