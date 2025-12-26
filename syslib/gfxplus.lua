-- Convert a normal 24-bit RGB hex color (#RRGGBB or RRGGBB) to RGB565 (0..65535)
local function hexConvert(hex)
    assert(type(hex) == "string", "hexConvert expects a string like '#RRGGBB'")
  
    hex = hex:gsub("^#", "")
    assert(#hex == 6, "hex color must be 6 hex digits (RRGGBB)")
  
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    assert(r and g and b, "invalid hex color")
  
    -- RGB888 -> RGB565 (truncate, common in embedded code)
    local rgb565 = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)
    return rgb565
end

local function clampInt(x, lo, hi)
    if x < lo then return lo end
    if x > hi then return hi end
    return x
end

-- Split RGB565 into channels:
--   r: 0..31, g: 0..63, b: 0..31
local function unpack565(c)
    c = c & 0xFFFF
    local r = (c >> 11) & 0x1F
    local g = (c >> 5) & 0x3F
    local b = c & 0x1F
    return r, g, b
end

local function pack565(r, g, b)
    r = r & 0x1F
    g = g & 0x3F
    b = b & 0x1F
    return (r << 11) | (g << 5) | b
end

-- Blend a foreground RGB565 color over a background RGB565 color, returning an RGB565 result.
-- opacity:
--   - 0..1 (float) OR 0..255 (int)
--   - 0 means fully background, 1/255 means fully foreground
local function withOpacity(fg565, bg565, opacity)
    assert(type(fg565) == "number" and type(bg565) == "number", "withOpacity expects (number fg565, number bg565, number opacity)")
    assert(type(opacity) == "number", "withOpacity opacity must be a number")

    local a
    if opacity <= 1 then
        a = math.floor(opacity * 255 + 0.5)
    else
        a = math.floor(opacity + 0.5)
    end
    a = clampInt(a, 0, 255)

    if a == 0 then return bg565 & 0xFFFF end
    if a == 255 then return fg565 & 0xFFFF end

    local fr, fg, fb = unpack565(fg565)
    local br, bg, bb = unpack565(bg565)

    -- out = bg + (fg - bg) * a
    -- done per-channel, with rounding.
    local r = math.floor((br * (255 - a) + fr * a + 127) / 255)
    local g = math.floor((bg * (255 - a) + fg * a + 127) / 255)
    local b = math.floor((bb * (255 - a) + fb * a + 127) / 255)

    return pack565(
        clampInt(r, 0, 31),
        clampInt(g, 0, 63),
        clampInt(b, 0, 31)
    )
end

  
return {
    hexConvert = hexConvert,
    withOpacity = withOpacity,
}