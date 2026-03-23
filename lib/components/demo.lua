-- vim: ft=lua:ts=4:sw=4:et:ai:cin
--
-- Demo mode: registers and applies demo definitions to mock component output.
-- Activated by setting `lcc.config.demo = true` in local.conf.
--
-- Components register demo behavior with:
--   lcc.demo.def(my_component, {
--       text_gsub = { { pattern, replacement }, ... },   -- conky.text replacements
--       vals         = { name = function, ... },         -- dynamic value providers (used by ${lua demo_val name})
--       conky_funcs  = { func_name = function, ... },    -- conky_* function overrides
--   })

local demo = {}

local _defs = {}
local _activated = {}
local _vals = {}
local _initialized = false

-- register a demo definition for a component
function demo.def(component, def)
    _defs[component] = def
end

-- activate demo mode for a component: patches the function and returns it
function demo.activate(func)
    if not _initialized then
        _G.conky_demo_val = function(name)
            local fn = _vals[name]
            return fn and tostring(fn()) or "0"
        end
        _initialized = true
    end

    if _activated[func] then return _activated[func] end

    local def = _defs[func]
    if not def then return func end

    -- register dynamic value providers
    if def.vals then
        for k, fn in pairs(def.vals) do
            _vals[k] = fn
        end
    end

    -- override conky_* globals
    if def.conky_funcs then
        for name, fn in pairs(def.conky_funcs) do
            _G["conky_" .. name] = fn
            lcc.log.debug("demo override:", "conky_" .. name)
        end
    end

    -- wrap with text replacements
    local result = func
    if def.text_gsub then
        result = function(...)
            local text = func(...)
            for _, r in ipairs(def.text_gsub) do
                text = text:gsub(r[1], r[2])
            end
            return text
        end
    end

    _activated[func] = result
    return result
end

return demo
