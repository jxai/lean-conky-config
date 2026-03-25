local utils = require("utils")

-------------------------------
-- conky interface functions --
-------------------------------

-- renders text with specified font and placement
-- `pla`: placement (position and alignment) formatted as '[l|c|r][<pos>]'
--        l/c/r indicates left/center/right alignment respectively, if not specified left is assumed
--        <pos> can be in pixel (scaled) from the left boundary of the rendering area or percentage
--        e,g, `33.3%`
--        if neither is provided, string is rendered inline with no specific placement
-- `font`: key of the desired font, e.g. "h1"
-- `text`: string to render
-- `alt_font`: alternative font if `font `is not found on the system, if neither found or both empty
--             the default font will be used
-- `alt_text`: alternative text to be rendered when `font` is unavailable - this offers flexibility
--             of displaying something different while handling a missing `font`. If `nil`, it is
--             assumed to be the same as `text`
-- NOTE: `font` and `alt_font` may include property overrides following the font key, e.g.
--       "icon:size=24" or "icon:bold:size=24", which replace all original font properties
function conky_text(...)
    return conky_parse(_conky_text(...))
end

function _conky_text(pla, font, text, alt_font, alt_text)
    -- `align`: 'l' - left, 'c' = center, 'r' - right, nil - inline
    -- `pos`: absolute postion of the text in physical (scaled) pixels
    local function _parse_placement(pla)
        if not pla then return end
        local align, pos_str = pla:lower():match("^([lcr]?)([+-]?%d*%.?%d*%%?)$")
        if not align then return end

        -- if position not specified, to align against whole width
        if pos_str == "" then
            if align == 'l' then
                pos_str = "0"
            elseif align == 'c' then
                pos_str = "50%"
            elseif align == 'r' then
                pos_str = "100%"
            else
                return
            end
        elseif align == "" then
            align = 'l'
        end
        local perc = tonumber(pos_str:match("^([%d%.]+)%%$"))
        if perc then return align, utils.round(perc / 100 * conky_window.text_width) end
        return align, tonumber(pos_str)
    end
    local align, pos = _parse_placement(pla)

    text = text and utils.unbrace(text) or ""
    if alt_text == nil then
        alt_text = text
    else
        alt_text = utils.unbrace(alt_text)
    end

    local function _resolve_font(font_arg)
        if not font_arg then return nil end
        font_arg = utils.unbrace(font_arg)

        local p = font_arg:find(":", 1, true)
        local prop = nil
        if p then
            prop = font_arg:sub(p)
            font_arg = font_arg:sub(1, p - 1)
        end
        local res = lcc.fonts[font_arg]
        if res and prop then
            res = res:match("^([^:]+)") .. prop
        end
        return res
    end
    local font_res     = _resolve_font(font)
    local alt_font_res = _resolve_font(alt_font)

    local function _render(_text, _font)
        if not _text then return end
        if not _font then _font = lcc.fonts.default end

        -- !! NOTICE !! clean_text must produce NO specials e.g. ${offset},
        -- ${font} etc. after being conky_parse'd, otherwise rendering may be
        -- broken
        local clean_text = utils.strip_specials(_text)

        local s = string.format("${font %s}%s", _font, _text)
        if align then
            local p = conky_window.text_start_x + pos
            local w = utils.text_width(conky_parse(clean_text), _font)
            if align == 'c' then
                p = p - utils.round(w / 2)
            elseif align == 'r' then
                p = p - w
            end
            s = string.format("${goto %d}", p) .. s
        end
        return s
    end
    if font_res then
        return _render(text, font_res)
    elseif alt_font_res then
        return _render(alt_text, alt_font_res)
    else
        return _render(alt_text)
    end
end

-- renders text at multiple tab stops on a single line using the same font
-- `font`: key of the desired font applied to all entries (see `conky_text`
--         for font key format); if not found, the default font is used.
-- `...`: variadic pairs of (placement, text) — at least one pair required;
--        each placement acts as a tab stop, positioning its text at a fixed column
--        e.g. conky_tab("h2", "l", "A", "c33%", "B", "r66%", "D", "r", "E")
function conky_tab(font, ...)
    local argc = select('#', ...)
    if argc < 2 then return end

    local s = ""
    for i = 1, math.floor(argc / 2) do
        s = s .. _conky_text((select(2 * i - 1, ...)), font, (select(2 * i, ...)))
    end
    return conky_parse(s)
end

-- variant of `conky_tab` that supports alt font and alt text
-- `font`, `alt_font`: see `conky_text` for font key format and fallback behavior
-- `...`: variadic triplets of (placement, text, alt_text)
function conky_tab_alt(font, alt_font, ...)
    local argc = select('#', ...)
    if argc < 3 then return end

    local s = ""
    for i = 1, math.floor(argc / 3) do
        s = s .. _conky_text((select(3 * i - 2, ...)), font, (select(3 * i - 1, ...)), alt_font, (select(3 * i, ...)))
    end
    return conky_parse(s)
end

-------------------------------------------------------------------------------
-- ! WARNING ! `conky_font`:
-- 1. it is now a thin wrapper of `conky_text`, which is preferred for text rendering
-- 2. the API will likely undergo an incompatible change with a future release
-------------------------------------------------------------------------------
function conky_font(font, text, alt_text, alt_font)
    return conky_text(nil, font, text, alt_font, alt_text)
end

-- echo arguments (verbatim with no parsing)
function conky_echo(...)
    return ...
end

-- wrapper of string.format
function conky_format(...)
    return string.format(...)
end

-- triming surrounding spaces
-- `text` must be pure text after being conky_parse'd
function conky_trim(text)
    return utils.trim(conky_parse(utils.unbrace(text)))
end

-- ratio as percentage
conky_ratio_perc = utils.ratio_perc
