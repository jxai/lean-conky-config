local utils = require("utils")
local core = require("components.core")
local weather = {}

-- weather component (wttr.in backend)
lcc.tpl.weather = [[
${lua weather {%= interv %} {{%= loc %}}}]]
function weather.wttrin(args)
    return lcc.tpl.weather {
        interv = utils.table.get(args, 'interval', 900),
        loc = utils.table.get(args, 'location', "auto"),
    }
end

-- weather component implementation
function conky_weather(interv, loc)
    -- `loc` might has spaces, has to be wrapped and then unbraced here
    loc = loc and utils.unbrace(loc) or "auto"
    return core._interval_call(interv, _weather_wttrin, loc)
end

-- wttr.in backend implementation
lcc.tpl.weather_wttrin =
[[${voffset $sr{-6}}${color}${lua text l { } icon_s icon_s_alt {⊙ }}${font}${voffset $sr{-1}}{%= wd.loc %}
${voffset $sr{10}}${lua text l {%= wd.icon[2] %} icon_l:size=$sr{30} icon_l_alt:size=$sr{27} {%= wd.icon[1] %}}${voffset $sr{-3}}${offset $sr{3}}${lua text {} {{%= wd.tempC %}℃} h1:size=$sr{20}}${font}
${voffset $sr{10}}{%= wd.desc %}{% local b,s=49,17 %}${voffset $sr{-86}}
{% for i, fc in ipairs(wd.fc) do +%}${lua text r{%= b+i*s %}% {%= fc.day %}}{% end %}${voffset $sr{5}}
{% for i, fc in ipairs(wd.fc) do +%}${lua text r{%= b+i*s %}% {%= fc.icon[2] %} icon_l icon_l_alt {%= fc.icon[1] %}}{% end %}${voffset $sr{-5}}
{% for i, fc in ipairs(wd.fc) do +%}${lua text r{%= b+i*s %}% {{%= fc.maxtempC %}℃} default:size=$sc{7}}{% end %}${voffset}
{% for i, fc in ipairs(wd.fc) do +%}${lua text r{%= b+i*s %}% {{%= fc.mintempC %}℃} default:size=$sc{7}}{% end %}${voffset $sr{7}}]]
function _weather_wttrin(loc)
    -- Code definitions: https://www.worldweatheronline.com/weather-api/api/docs/weather-icons.aspx
    function _weather_icon(code)
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

    function _day_of_week(date)
        local t = utils.time_from_str(date)
        if t == nil then return "???" else return os.date("%a", t) end
    end

    lcc.log.debug("fetching weather for: " .. loc)
    if loc:lower() == "auto" then
        local d = utils.json.curl("ip-api.com/json") -- more accurate auto location
        if d then
            loc = utils.join_strs({ d.city, d.region, d.countryCode }, " ")
            -- loc = string.format("%f,%f", tonumber(d.lat), tonumber(d.lon)) -- not working if latlon not precise
        else
            lcc.log.warn("ip-api geolocation failed, deferring to wttr.in")
            loc = ""
        end
    end

    local w = utils.json.curl("wttr.in/" .. loc:gsub("%s+", "+") .. "?format=j1")
    if w then
        if w.data then w = w.data end -- workaround for unexpected wttr.in response format change
        local forecast = {}
        for i = 1, 3 do
            local fw = w.weather[i]
            local fc = fw.hourly[5] -- condition forecast at noon
            forecast[i] = {
                day = _day_of_week(fw.date):upper(),
                desc = fc.weatherDesc[1].value,
                code = fc.weatherCode,
                icon = _weather_icon(fc.weatherCode),
                maxtempC = fw.maxtempC,
                mintempC = fw.mintempC,
                maxtempF = fw.maxtempF,
                mintempF = fw.mintempF,
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
            tempC = c.temp_C,
            tempF = c.temp_F,
            hum = c.humidity,
            fc = forecast,
        }
        lcc.log.debug("weather fetched for location: " .. actual_loc)
        return lcc.tpl.weather_wttrin { wd = weather_data }
    else
        lcc.log.warn("wttr.in fetch failed for location: " .. loc)
        return "ERROR: Failed to fetch weather data"
    end
end

-- shortcut: weather -> weather.wttrin
setmetatable(weather, {
    __call = function(_, ...)
        return weather.wttrin(...)
    end
})

return weather
