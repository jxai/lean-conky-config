local utils = require("utils")
local core = require("components.core")

-- weather: interface
lcc.tpl.weather_wrapper = [[
${lua weather {%= interv %} {%= backend %} {{%= loc %}} {%= metric %}}]]
function weather(args)
    return lcc.tpl.weather_wrapper {
        interv = utils.table.get(args, 'interval', 900),
        backend = utils.table.get(args, 'backend', 'wttrin'),
        loc = utils.table.get(args, 'location', "auto"),
        metric = utils.table.get(args, 'metric', 1),
    }
end

-- weather: dispatcher
function conky_weather(interv, backend, loc, metric)
    loc = loc and utils.unbrace(loc) or "auto" -- loc is {} wrapped, has to be unbraced here
    metric = (tonumber(metric) == 1)

    local rendered = core._interval_call(interv, _weather, backend, loc, metric)
    if rendered then return rendered end

    return conky_parse(core.message("error+",
        "\nWeather failed to load" ..
        "\nData service (" .. backend .. ") might be invalid or broken"
    ))
end

-- weather: implementation
lcc.tpl.weather = -- p:info offset b:forecast offset s:forecast spacing
[[{% local p,b,s=$sr{58},49,17 %}${voffset $sr{-6}}${color}${lua text l { } icon_s icon_s_alt {⊙ }}${font}${voffset $sr{-1}}{%= wd.loc %}
${lua text l {{%= wd.desc %}} default:size=$sc{7}}
${voffset $sr{5}}${lua text l {%= wd.icon[2] %} icon_l:size=$sr{32} icon_l_alt:size=$sr{30} {%= wd.icon[1] %}}
${voffset $sr{-64}}${lua text l{%= p %} {{%= wd.temp %}} h1:size=$sr{20}}
${voffset $sr{-21}}{% if wd.has_precip then +%}${lua text l{%= p %} {${voffset $sr{-1}}} icon_s icon_s_alt {☔${voffset $sr{1}}}}${font} {%= wd.precip %}{% else +%}${lua text l{%= p %} {${voffset $sr{-1}}} icon_s icon_s_alt {◑${voffset $sr{1}}}}${font} {%= wd.hum %}%{% end %}
${voffset $sr{16}}${lua text l{%= p %} {${voffset $sr{-1}}} icon_s icon_s_alt {≈${voffset $sr{1}}}}${font}${voffset $sr{-1}} {%= wd.wind %} {%= wd.winddir %}${voffset $sr{-84}}
{% for i, fc in ipairs(wd.fc) do +%}${lua text r{%= b+i*s %}% {%= fc.day %}}{% end %}${voffset $sr{5}}
{% for i, fc in ipairs(wd.fc) do +%}${lua text r{%= b+i*s %}% {%= fc.icon[2] %} icon_l icon_l_alt {%= fc.icon[1] %}}{% end %}${voffset $sr{-5}}
{% for i, fc in ipairs(wd.fc) do +%}${lua text r{%= b+i*s %}% {{%= fc.maxtemp %}} default:size=$sc{7}}{% end %}${voffset}
{% for i, fc in ipairs(wd.fc) do +%}${lua text r{%= b+i*s %}% {{%= fc.mintemp %}} default:size=$sc{7}}{% end %}${voffset $sr{7}}]]
function _weather(backend, loc, metric)
    if loc:lower() == "auto" then
        lcc.log.debug("auto detecting geolocation")
        local d = utils.json.curl("ip-api.com/json") -- more accurate auto location
        if d then
            loc = utils.join_strs({ d.city, d.region, d.countryCode }, " ")
            -- loc = string.format("%f,%f", tonumber(d.lat), tonumber(d.lon)) -- not working if latlon not precise
        else
            lcc.log.warn("ip-api geolocation failed, deferring to weather backend")
        end
    end
    lcc.log.debug("fetching weather data from", backend, "backend for location:", loc)
    if backend == 'wttrin' then
        backend = fetch_weather_wttrin
    else
        lcc.log.error("invalid weather backend: ", backend)
        return
    end

    local weather_data, actual_loc = backend(loc, metric)
    if weather_data then
        lcc.log.debug("weather fetched for actual location:", actual_loc)
        return lcc.tpl.weather { wd = weather_data }
    else
        lcc.log.warn("failed to fetch weather for location: " .. loc)
    end
end

-- helper functions --
local function _weather_icon(code)
    -- code definitions: https://www.worldweatheronline.com/weather-api/api/docs/weather-icons.aspx
    local icons = {
        ['113'] = { "☀", "", "" }, -- Clear/Sunny
        ['116'] = { "☁", "", "" }, -- Partly Cloudy
        ['119'] = { "☁", "", "" }, -- Cloudy
        ['122'] = { "☁", "", "" }, -- Overcast
        ['143'] = { "≡", "", "" }, -- Mist
        ['176'] = { "☔", "", "" }, -- Patchy rain nearby
        ['179'] = { "❄", "", "" }, -- Patchy snow nearby
        ['182'] = { "☔", "", "" }, -- Patchy sleet nearby
        ['185'] = { "☔", "", "" }, -- Patchy freezing drizzle nearby
        ['200'] = { "⚡", "", "" }, -- Thundery outbreaks in nearby
        ['227'] = { "❄", "", "" }, -- Blowing snow
        ['230'] = { "❄", "", "" }, -- Blizzard
        ['248'] = { "≡", "", "" }, -- Fog
        ['260'] = { "≡", "", "" }, -- Freezing fog
        ['263'] = { "☔", "", "" }, -- Patchy light drizzle
        ['266'] = { "☔", "", "" }, -- Light drizzle
        ['281'] = { "☔", "", "" }, -- Freezing drizzle
        ['284'] = { "☔", "", "" }, -- Heavy freezing drizzle
        ['293'] = { "☔", "", "" }, -- Patchy light rain
        ['296'] = { "☔", "", "" }, -- Light rain
        ['299'] = { "☔", "", "" }, -- Moderate rain at times
        ['302'] = { "☔", "", "" }, -- Moderate rain
        ['305'] = { "☔", "", "" }, -- Heavy rain at times
        ['308'] = { "☔", "", "" }, -- Heavy rain
        ['311'] = { "☔", "", "" }, -- Light freezing rain
        ['314'] = { "☔", "", "" }, -- Moderate or heavy freezing rain
        ['317'] = { "☔", "", "" }, -- Light sleet
        ['320'] = { "☔", "", "" }, -- Moderate or heavy sleet
        ['323'] = { "❄", "", "" }, -- Patchy light snow
        ['326'] = { "❄", "", "" }, -- Light snow
        ['329'] = { "❄", "", "" }, -- Patchy moderate snow
        ['332'] = { "❄", "", "" }, -- Moderate snow
        ['335'] = { "❄", "", "" }, -- Patchy heavy snow
        ['338'] = { "❄", "", "" }, -- Heavy snow
        ['350'] = { "❄", "", "" }, -- Ice pellets
        ['353'] = { "☔", "", "" }, -- Light rain shower
        ['356'] = { "☔", "", "" }, -- Moderate or heavy rain shower
        ['359'] = { "☔", "", "" }, -- Torrential rain shower
        ['362'] = { "☔", "", "" }, -- Light sleet showers
        ['365'] = { "☔", "", "" }, -- Moderate or heavy sleet showers
        ['368'] = { "❄", "", "" }, -- Light snow showers
        ['371'] = { "❄", "", "" }, -- Moderate or heavy snow showers
        ['374'] = { "☔", "", "" }, -- Light showers of ice pellets
        ['377'] = { "☔", "", "" }, -- Moderate or heavy showers of ice pellets
        ['386'] = { "⚡", "", "" }, -- Patchy light rain in area with thunder
        ['389'] = { "⚡", "", "" }, -- Moderate or heavy rain in area with thunder
        ['392'] = { "⚡", "", "" }, -- Patchy light snow in area with thunder
        ['395'] = { "⚡", "", "" }, -- Moderate or heavy snow in area with thunder
    }
    return utils.table.get(icons, code)
end

local function _day_of_week(date)
    local t = utils.time_from_str(date)
    if t == nil then return "???" else return os.date("%a", t) end
end

local function _format_temp(metric, tempC, tempF)
    return metric and tostring(tempC) .. "℃" or tostring(tempF) .. "℉"
end

-- weather backend - wttr.in
function fetch_weather_wttrin(loc, metric)
    loc = loc:lower() == "auto" and "" or loc:gsub("%s+", "+") -- normalize loc for wttr.in
    local w = utils.json.curl("wttr.in/" .. loc .. "?format=j1")
    if w then
        if w.data then w = w.data end -- workaround for unexpected wttr.in response format change
        local forecast = {}
        for i = 1, 3 do
            local fw = w.weather[i] -- forecast weather of day i
            local fc = fw.hourly[5] -- forecast condition at noon
            forecast[i] = {
                day = _day_of_week(fw.date):upper(),
                desc = fc.weatherDesc[1].value,
                code = fc.weatherCode,
                icon = _weather_icon(fc.weatherCode),
                maxtemp = _format_temp(metric, fw.maxtempC, fw.maxtempF),
                mintemp = _format_temp(metric, fw.mintempC, fw.mintempF),
            }
        end

        local actual_loc, geo
        if w.nearest_area then
            geo = w.nearest_area[1]
            actual_loc = geo and utils.join_strs({ geo.areaName[1].value, geo.region[1].value }, ", ")
        elseif w.request and w.request[1] and w.request[1].type == "LatLon" and w.request[1].query then
            local lat, lon = w.request[1].query:lower():match("lat (%d*%.?%d*).+ lon ([+-]?%d*%.?%d*)")
            lat, lon = tonumber(lat), tonumber(lon)
            if lat and lon then
                geo = utils.reverse_geocode(lat, lon)
                actual_loc = geo and utils.join_strs({ geo.city, geo.principalSubdivision }, ", ")
            end
        end
        if not actual_loc then actual_loc = loc end -- last resort

        local c = w.current_condition[1]
        local weather_data = {
            loc = actual_loc,
            desc = c.weatherDesc[1].value,
            code = c.weatherCode,
            icon = _weather_icon(c.weatherCode),
            temp = _format_temp(metric, c.temp_C, c.temp_F),
            hum = c.humidity,
            wind = metric and c.windspeedKmph .. " km/h" or c.windspeedMiles .. " mph",
            winddir = c.winddir16Point,
            has_precip = (tonumber(c.precipMM) or 0) > 0,
            precip = metric and c.precipMM .. " mm" or c.precipInches .. " in",
            fc = forecast,
        }
        return weather_data, actual_loc
    end
end

return weather
