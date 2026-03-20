--
-- log.lua
--
-- Copyright (c) 2016 rxi
-- Copyright (c) 2026 jxai
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local log = { _version = "0.2.0" }

log.level = "trace"
log.usecolor = true
log.outfile = nil
log.stderr = false
log.tostr = nil


local modes = {
  { name = "trace", color = "\27[34m", },
  { name = "debug", color = "\27[36m", },
  { name = "info",  color = "\27[32m", },
  { name = "warn",  color = "\27[33m", },
  { name = "error", color = "\27[31m", },
  { name = "fatal", color = "\27[35m", },
}


local levels = {}
for i, v in ipairs(modes) do
  levels[v.name] = i
end


local round = function(x, increment)
  increment = increment or 1
  x = x / increment
  return (x > 0 and math.floor(x + .5) or math.ceil(x - .5)) * increment
end


local make_msg = function(tostr, ...)
  local t = {}
  for i = 1, select('#', ...) do
    local x = select(i, ...)
    if tostr then
      t[#t + 1] = tostr(x)
    else
      if type(x) == "number" then x = round(x, .01) end
      t[#t + 1] = tostring(x)
    end
  end
  return table.concat(t, " ")
end


local noop = function() end

-- attach_log_methods(instance, extra_mt):
--   Builds one real implementation per log level and stores them in a closure.
--   apply_level() rawsets each mode key to either the real impl or noop, so
--   calls to disabled levels cost nothing beyond a table lookup.
--   `level` is kept out of the raw table so that __newindex always intercepts
--   assignments and triggers apply_level() automatically.
--   extra_mt allows the caller to inject additional metamethods (e.g. __call
--   on the singleton) into the same metatable.
local function attach_log_methods(instance, extra_mt)
  local current_level = instance.level
  local current_name  = instance.name
  local impls         = {}

  -- Build real implementations upfront, closed over `instance`.
  for i, x in ipairs(modes) do
    local nameupper = x.name:upper()
    impls[i] = function(...)
      local msg = make_msg(instance.tostr, ...)
      local info = debug.getinfo(2, "Sl")
      local lineinfo = info.short_src .. ":" .. info.currentline
      local prefix = current_name and current_name .. ":" or ""

      -- Output to console
      local out = instance.stderr and io.stderr or io.stdout
      out:write(string.format("%s[%-6s%s]%s %s%s: %s\n",
        instance.usecolor and x.color or "",
        nameupper,
        os.date("%H:%M:%S"),
        instance.usecolor and "\27[0m" or "",
        prefix,
        lineinfo,
        msg))

      -- Output to log file
      if instance.outfile then
        local fp, err = io.open(instance.outfile, "a")
        if not fp then error("could not open log file: " .. err) end
        local str = string.format("[%-6s%s] %s%s: %s\n",
          nameupper, os.date(), prefix, lineinfo, msg)
        fp:write(str)
        fp:close()
      end
    end
  end

  local function apply_level(level)
    local threshold = levels[level]
    if not threshold then
      error("invalid log level: " .. tostring(level), 2)
    end
    for i, x in ipairs(modes) do
      rawset(instance, x.name, i >= threshold and impls[i] or noop)
    end
  end

  -- Remove level and name from the raw table so __newindex always fires for them.
  rawset(instance, "level", nil)
  rawset(instance, "name", nil)

  local mt = extra_mt or {}
  mt.__index = function(_, k)
    if k == "level" then return current_level end
    if k == "name" then return current_name end
  end
  mt.__newindex = function(t, k, v)
    if k == "level" then
      current_level = v
      apply_level(v)
    elseif k == "name" then
      error("name is read-only after creation", 2)
    else
      rawset(t, k, v)
    end
  end
  setmetatable(instance, mt)

  apply_level(current_level)
end


-- Attach methods to the global logger. Pass the __call metamethod in the same
-- table so the singleton ends up with a single combined metatable.
attach_log_methods(log, {
  __call = function(_, config)
    config = config or {}
    local usecolor = config.usecolor
    if usecolor == nil then usecolor = log.usecolor end
    local instance = {
      name     = config.name,
      level    = config.level or log.level,
      usecolor = usecolor,
      outfile  = config.outfile or log.outfile,
      stderr   = config.stderr ~= nil and config.stderr or log.stderr,
      tostr    = config.tostr or log.tostr,
    }
    attach_log_methods(instance)
    return instance
  end
})


return log
