local utils = require("utils")
local core = require("components.core")

-- WWO weather code -> { fallback_icon, icon_font_primary, icon_font_solid }
-- code definitions: https://www.worldweatheronline.com/weather-api/api/docs/weather-icons.aspx
local WWO_ICONS = {
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

-- WMO 4677 code -> { description, wwo_mapping }
local WMO_MAP = {
    -- 00-09: sky / visibility
    [0] = { "Clear sky", '113' },                      -- Clear/Sunny
    [1] = { "Mainly clear", '113' },                   -- Clear/Sunny
    [2] = { "Partly cloudy", '116' },                  -- Partly Cloudy
    [3] = { "Overcast", '122' },                       -- Overcast
    [4] = { "Smoke haze", '143' },                     -- Mist (no smoke in WWO)
    [5] = { "Haze", '143' },                           -- Mist
    [6] = { "Widespread dust", '143' },                -- Mist
    [7] = { "Dust raised by wind", '143' },            -- Mist
    [8] = { "Dust whirls", '143' },                    -- Mist
    [9] = { "Duststorm", '143' },                      -- Mist
    -- 10-19: observation phenomena
    [10] = { "Mist", '143' },                          -- Mist
    [11] = { "Shallow fog patches", '143' },           -- Mist
    [12] = { "Shallow fog", '248' },                   -- Fog
    [13] = { "Lightning", '200' },                     -- Thundery outbreaks
    [14] = { "Distant precipitation", '176' },         -- Patchy rain nearby
    [15] = { "Distant precipitation", '176' },         -- Patchy rain nearby
    [16] = { "Nearby precipitation", '176' },          -- Patchy rain nearby
    [17] = { "Thunderstorm", '200' },                  -- Thundery outbreaks
    [18] = { "Squalls", '308' },                       -- Heavy rain
    [19] = { "Tornado", '200' },                       -- Thundery outbreaks
    -- 20-29: ended in past hour
    [20] = { "Recent drizzle", '263' },                -- Patchy light drizzle
    [21] = { "Recent rain", '293' },                   -- Patchy light rain
    [22] = { "Recent snow", '323' },                   -- Patchy light snow
    [23] = { "Recent sleet", '182' },                  -- Patchy sleet nearby
    [24] = { "Recent freezing rain", '185' },          -- Patchy freezing drizzle
    [25] = { "Recent rain showers", '176' },           -- Patchy rain nearby
    [26] = { "Recent snow showers", '179' },           -- Patchy snow nearby
    [27] = { "Recent hail", '176' },                   -- Patchy rain nearby
    [28] = { "Recent fog", '248' },                    -- Fog
    [29] = { "Recent thunderstorm", '200' },           -- Thundery outbreaks
    -- 30-39: duststorm / blowing snow
    [30] = { "Duststorm, decreasing", '143' },         -- Mist
    [31] = { "Duststorm", '143' },                     -- Mist
    [32] = { "Duststorm, increasing", '143' },         -- Mist
    [33] = { "Severe duststorm, decreasing", '143' },  -- Mist
    [34] = { "Severe duststorm", '143' },              -- Mist
    [35] = { "Severe duststorm, increasing", '143' },  -- Mist
    [36] = { "Blowing snow, low", '227' },             -- Blowing snow
    [37] = { "Heavy drifting snow, low", '230' },      -- Blizzard
    [38] = { "Blowing snow, high", '227' },            -- Blowing snow
    [39] = { "Heavy drifting snow, high", '230' },     -- Blizzard
    -- 40-49: fog
    [40] = { "Distant fog", '143' },                   -- Mist
    [41] = { "Patchy fog", '248' },                    -- Fog
    [42] = { "Fog, thinning", '248' },                 -- Fog
    [43] = { "Dense fog, thinning", '248' },           -- Fog
    [44] = { "Fog", '248' },                           -- Fog
    [45] = { "Fog", '248' },                           -- Fog
    [46] = { "Fog, thickening", '248' },               -- Fog
    [47] = { "Dense fog, thickening", '248' },         -- Fog
    [48] = { "Rime fog", '260' },                      -- Freezing fog
    [49] = { "Dense rime fog", '260' },                -- Freezing fog
    -- 50-59: drizzle
    [50] = { "Intermittent light drizzle", '263' },    -- Patchy light drizzle
    [51] = { "Light drizzle", '266' },                 -- Light drizzle
    [52] = { "Intermittent moderate drizzle", '263' }, -- Patchy light drizzle
    [53] = { "Moderate drizzle", '266' },              -- Light drizzle
    [54] = { "Intermittent heavy drizzle", '296' },    -- Light rain (heavy drizzle ≈ light rain)
    [55] = { "Heavy drizzle", '296' },                 -- Light rain
    [56] = { "Light freezing drizzle", '281' },        -- Freezing drizzle
    [57] = { "Heavy freezing drizzle", '284' },        -- Heavy freezing drizzle
    [58] = { "Light drizzle and rain", '296' },        -- Light rain
    [59] = { "Heavy drizzle and rain", '302' },        -- Moderate rain
    -- 60-69: rain
    [60] = { "Intermittent light rain", '293' },       -- Patchy light rain
    [61] = { "Light rain", '296' },                    -- Light rain
    [62] = { "Intermittent moderate rain", '299' },    -- Moderate rain at times
    [63] = { "Moderate rain", '302' },                 -- Moderate rain
    [64] = { "Intermittent heavy rain", '305' },       -- Heavy rain at times
    [65] = { "Heavy rain", '308' },                    -- Heavy rain
    [66] = { "Light freezing rain", '311' },           -- Light freezing rain
    [67] = { "Heavy freezing rain", '314' },           -- Heavy freezing rain
    [68] = { "Light sleet", '317' },                   -- Light sleet
    [69] = { "Heavy sleet", '320' },                   -- Heavy sleet
    -- 70-79: snow
    [70] = { "Intermittent light snow", '323' },       -- Patchy light snow
    [71] = { "Light snow", '326' },                    -- Light snow
    [72] = { "Intermittent moderate snow", '329' },    -- Patchy moderate snow
    [73] = { "Moderate snow", '332' },                 -- Moderate snow
    [74] = { "Intermittent heavy snow", '335' },       -- Patchy heavy snow
    [75] = { "Heavy snow", '338' },                    -- Heavy snow
    [76] = { "Diamond dust", '323' },                  -- Patchy light snow
    [77] = { "Snow grains", '323' },                   -- Patchy light snow
    [78] = { "Ice crystals", '323' },                  -- Patchy light snow
    [79] = { "Ice pellets", '350' },                   -- Ice pellets
    -- 80-90: showers
    [80] = { "Light rain showers", '353' },            -- Light rain shower
    [81] = { "Heavy rain showers", '356' },            -- Heavy rain shower
    [82] = { "Torrential rain showers", '359' },       -- Torrential rain shower
    [83] = { "Light sleet showers", '362' },           -- Light sleet showers
    [84] = { "Heavy sleet showers", '365' },           -- Heavy sleet showers
    [85] = { "Light snow showers", '368' },            -- Light snow showers
    [86] = { "Heavy snow showers", '371' },            -- Heavy snow showers
    [87] = { "Light hail showers", '374' },            -- Light ice pellet showers
    [88] = { "Heavy hail showers", '377' },            -- Heavy ice pellet showers
    [89] = { "Light hail", '374' },                    -- Light ice pellet showers
    [90] = { "Heavy hail", '377' },                    -- Heavy ice pellet showers
    -- 91-99: thunderstorms
    [91] = { "Light rain, recent thunder", '386' },    -- Light rain with thunder
    [92] = { "Heavy rain, recent thunder", '389' },    -- Heavy rain with thunder
    [93] = { "Light snow, recent thunder", '392' },    -- Light snow with thunder
    [94] = { "Heavy snow, recent thunder", '395' },    -- Heavy snow with thunder
    [95] = { "Thunderstorm", '386' },                  -- Light rain with thunder
    [96] = { "Thunderstorm with hail", '386' },        -- Light rain with thunder
    [97] = { "Heavy thunderstorm", '389' },            -- Heavy rain with thunder
    [98] = { "Thunderstorm with duststorm", '200' },   -- Thundery outbreaks
    [99] = { "Heavy thunderstorm with hail", '395' },  -- Heavy snow with thunder
}
local WMO_FALLBACK = { "Unknown", '119' }              -- fallback for unknown weather codes

local WEATHER_UNITS = {
    metric   = { temp = "℃", wind = " km/h", precip = " mm" },
    imperial = { temp = "℉", wind = " mph", precip = " in" },
}


-- helper functions --
local function _day_of_week(date)
    local t = utils.time_from_str(date)
    if t == nil then return "???" else return os.date("%a", t) end
end

local function _deg_to_compass(deg)
    local dirs = { "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW" }
    return dirs[math.floor((deg / 22.5) + 0.5) % 16 + 1]
end

-- weather backend - wttr.in
local function fetch_weather_wttrin(loc, metric)
    local u = WEATHER_UNITS[metric and "metric" or "imperial"]
    local url = "https://wttr.in/" .. (loc:lower() == "auto" and "" or loc:gsub("%s+", "+")) .. "?format=j1"
    lcc.log.trace("fetching:", url)
    local w = utils.json.curl(url)
    if w then
        if w.data then w = w.data end -- workaround for unexpected wttr.in response format change
        local forecast = {}
        for i = 1, 3 do
            local fw = w.weather[i] -- forecast weather of day i
            local fc = fw.hourly[5] -- forecast condition at noon
            forecast[i] = {
                day = _day_of_week(fw.date):upper(),
                desc = fc.weatherDesc[1].value,
                icon = WWO_ICONS[fc.weatherCode],
                maxtemp = (metric and fw.maxtempC or fw.maxtempF) .. u.temp,
                mintemp = (metric and fw.mintempC or fw.mintempF) .. u.temp,
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
        actual_loc = actual_loc or loc -- last resort

        local c = w.current_condition[1]
        local weather_data = {
            loc = actual_loc,
            desc = c.weatherDesc[1].value,
            icon = WWO_ICONS[c.weatherCode],
            temp = (metric and c.temp_C or c.temp_F) .. u.temp,
            hum = c.humidity,
            wind = (metric and c.windspeedKmph or c.windspeedMiles) .. u.wind,
            winddir = c.winddir16Point,
            has_precip = (tonumber(c.precipMM) or 0) > 0,
            precip = (metric and c.precipMM or c.precipInches) .. u.precip,
            fc = forecast,
        }
        return weather_data, actual_loc
    end
end


-- weather backend - open-meteo
local function fetch_weather_openmeteo(loc, metric)
    -- geocode location string to lat/lon
    local lat, lon, actual_loc
    lat, lon = loc:match("^([%-%.%d]+)%s*,%s*([%-%.%d]+)$")
    if lat then lat, lon = tonumber(lat), tonumber(lon) end
    if not (lat and lon) then
        local url = "https://nominatim.openstreetmap.org/search?q=" .. loc:gsub("%s+", "+") .. "&format=json&limit=1"
        lcc.log.trace("nominatim geocoding:", url)
        local geo = utils.json.curl(url)
        if geo and geo[1] then
            lat, lon = tonumber(geo[1].lat), tonumber(geo[1].lon)
        else
            lcc.log.warn("nominatim geocoding failed for:", loc)
            return
        end
    end

    local geo = utils.reverse_geocode(lat, lon)
    actual_loc = geo and utils.join_strs({ geo.city, geo.principalSubdivision }, ", ") or loc

    local u = WEATHER_UNITS[metric and "metric" or "imperial"]
    local url = string.format(
        "https://api.open-meteo.com/v1/forecast?latitude=%f&longitude=%f"
        .. "&current=temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m,precipitation,weather_code"
        .. "&daily=temperature_2m_max,temperature_2m_min,weather_code"
        .. "&temperature_unit=%s&wind_speed_unit=%s&precipitation_unit=%s"
        .. "&timezone=auto&forecast_days=3",
        lat, lon,
        metric and "celsius" or "fahrenheit",
        metric and "kmh" or "mph",
        metric and "mm" or "inch")
    lcc.log.trace("fetching:", url)
    local w = utils.json.curl(url)
    if not w then return end

    local c = w.current
    local wmo = c.weather_code
    local precip = c.precipitation

    local forecast = {}
    for i = 1, 3 do
        local fc_wmo = w.daily.weather_code[i]
        forecast[i] = {
            day = _day_of_week(w.daily.time[i]):upper(),
            desc = (WMO_MAP[fc_wmo] or WMO_FALLBACK)[1],
            icon = WWO_ICONS[(WMO_MAP[fc_wmo] or WMO_FALLBACK)[2]],
            maxtemp = math.floor(w.daily.temperature_2m_max[i] + 0.5) .. u.temp,
            mintemp = math.floor(w.daily.temperature_2m_min[i] + 0.5) .. u.temp,
        }
    end

    local weather_data = {
        loc = actual_loc,
        desc = (WMO_MAP[wmo] or WMO_FALLBACK)[1],
        icon = WWO_ICONS[(WMO_MAP[wmo] or WMO_FALLBACK)[2]],
        temp = math.floor(c.temperature_2m + 0.5) .. u.temp,
        hum = tostring(c.relative_humidity_2m),
        wind = math.floor(c.wind_speed_10m + 0.5) .. u.wind,
        winddir = _deg_to_compass(c.wind_direction_10m),
        has_precip = precip > 0,
        precip = string.format("%.1f", precip) .. u.precip,
        fc = forecast,
    }
    return weather_data, actual_loc
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
local function _weather(backend, loc, metric)
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
    elseif backend == 'openmeteo' then
        backend = fetch_weather_openmeteo
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

-- weather: dispatcher
function conky_weather(interv, backend, loc, metric)
    loc = loc and utils.unbrace(loc) or "auto" -- loc is {} wrapped, has to be unbraced here
    metric = (tonumber(metric) == 1)

    local rendered = core._interval_call(interv, _weather, backend, loc, metric)
    if rendered then return rendered end

    return conky_parse(core.message("error+",
        "\nWeather failed to load" ..
        "\nBackend (" .. backend .. ") invalid or service broken"
    ))
end

-- weather: interface
lcc.tpl.weather_wrapper = [[
${lua weather {%= interv %} {%= backend %} {{%= loc %}} {%= metric %}}]]
local function weather(args)
    return lcc.tpl.weather_wrapper {
        interv = utils.table.get(args, 'interval', 900),
        backend = utils.table.get(args, 'backend', 'openmeteo'),
        loc = utils.table.get(args, 'location', "auto"),
        metric = utils.table.get(args, 'metric', 1),
    }
end

lcc.demo.def(weather, { -- demo: London weather with 3-day forecast
    conky_funcs = {
        weather = function(_interv, _backend, _loc, _metric)
            -- minimal subset of WWO icons (from weather.lua WWO_ICONS)
            local icons = {
                sunny         = { "☀", "", "" }, -- WWO 113
                partly_cloudy = { "☁", "", "" }, -- WWO 116
                light_rain    = { "☔", "", "" }, -- WWO 296
            }
            return conky_parse(lcc.tpl.weather { wd = {
                loc = "London, England",
                desc = "Partly cloudy",
                icon = icons.partly_cloudy,
                temp = "15℃",
                hum = "72",
                wind = "15 km/h",
                winddir = "SW",
                has_precip = false,
                precip = "0.0 mm",
                fc = {
                    { day = "MON", icon = icons.sunny, maxtemp = "17℃", mintemp = "10℃" },
                    { day = "TUE", icon = icons.light_rain, maxtemp = "13℃", mintemp = "8℃" },
                    { day = "WED", icon = icons.partly_cloudy, maxtemp = "15℃", mintemp = "9℃" },
                },
            } })
        end,
    },
})

return weather
