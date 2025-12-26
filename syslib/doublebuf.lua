-- syslib/doublebuf.lua
--
-- Optional sprite/backbuffer wrapper.
--
-- Why:
--   On SPI LCDs (like the M5Cardputer's ST7789), direct drawing often flickers because
--   the display is showing the framebuffer while you "clear then draw" each frame.
--   The fix is to render into an off-screen buffer (a sprite/canvas), then push the
--   finished frame to the display in one shot.

local M = {}

local function hasSpriteAPI(gfx)
    return type(gfx) == "table" and type(gfx.newSprite) == "function"
end

function M.new(gfx, w, h)
    if hasSpriteAPI(gfx) then
        local sprite = gfx.newSprite(w, h)

        local g = {
            clear = function(c) return sprite:clear(c) end,
            setTextColor = function(fg, bg) return sprite:setTextColor(fg, bg) end,
            setTextSize = function(sz) return sprite:setTextSize(sz) end,
            drawString = function(text, x, y) return sprite:drawString(text, x, y) end,
            drawCenterString = function(text, x, y) return sprite:drawCenterString(text, x, y) end,
        }

        return {
            g = g,
            isBuffered = true,
            present = function()
                -- Push the completed frame. If your binding supports DMA, this should use it.
                return sprite:push(0, 0)
            end,
            free = function()
                if sprite and type(sprite.free) == "function" then sprite:free() end
            end,
        }
    end

    -- Unbuffered fallback: proxy directly to gfx's module-level functions.
    local g = {
        clear = function(c) return gfx.clear(c) end,
        setTextColor = function(fg, bg) return gfx.setTextColor(fg, bg) end,
        setTextSize = function(sz) return gfx.setTextSize(sz) end,
        drawString = function(text, x, y) return gfx.drawString(text, x, y) end,
        drawCenterString = function(text, x, y) return gfx.drawCenterString(text, x, y) end,
    }

    return {
        g = g,
        isBuffered = false,
        present = function() end,
        free = function() end,
    }
end

return M


