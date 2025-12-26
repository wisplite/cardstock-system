local gfx = require("gfx")
local anim = require("anim")
local keyboard = require("keyboard")
local gfxplus = require("gfxplus")
local doublebuf = require("doublebuf")
local width = gfx.width()
local height = gfx.height()
local GREY = gfxplus.hexConvert("#c1c1c1")
local buf = doublebuf.new(gfx, width, height)
local g = buf.g

-- Simple screen state + "dirty" redraw flag to avoid full-screen clearing every frame
local screen = "welcome" -- "welcome" | "testing"
local dirty = true
local transitioning = false

-- Frame limiting for animations to reduce visible "clear then draw" flicker on non-double-buffered displays.
local TARGET_FPS = 30
local STEP = 1 / TARGET_FPS
local acc = 0

local inputArmed = false
local wasPressed = false

local screenOpacity = { value = 1 }
local a = anim.new()

local function drawWelcome()
    g.clear(0xFFFF)
    g.setTextColor(gfxplus.withOpacity(0x0000, 0xFFFF, screenOpacity.value), 0xFFFF)
    g.setTextSize(2)
    g.drawCenterString("Welcome", math.floor(width / 2), math.floor(height / 2) - 15)
    g.setTextSize(1)
    g.drawCenterString("Press any button to continue", math.floor(width / 2), math.floor(height / 2) + 10)
    g.setTextColor(gfxplus.withOpacity(GREY, 0xFFFF, screenOpacity.value), 0xFFFF)
    g.setTextSize(1)
    g.drawString("Paper Launcher v0.0.1", 5, height - 10)
end

local function drawTesting()
    g.clear(0xFFFF)
    g.setTextColor(gfxplus.withOpacity(0x0000, 0xFFFF, screenOpacity.value), 0xFFFF)
    g.setTextSize(2)
    g.drawCenterString("Testing", math.floor(width / 2), math.floor(height / 2) - 15)
end

function init()
    -- Draw once on boot
    screen = "welcome"
    dirty = true
end

function tick(dt)
    local pressed = keyboard.isPressed() > 0

    -- Don't accept input until we see a clean "no keys pressed" state at least once.
    if not inputArmed then
        if not pressed then
            inputArmed = true
        end
        wasPressed = pressed
        return
    end

    local justPressed = pressed and (not wasPressed)
    wasPressed = pressed

    if screen == "welcome" and justPressed and (not transitioning) then
        transitioning = true

        -- Ensure we don't stack multiple tweens/timers for the same property.
        a:clear()
        screenOpacity.value = 1

        a:to(screenOpacity, { value = 0 }, 1, {
            ease = anim.ease.outCubic,
            onComplete = function()
                screen = "testing"
                dirty = true
                a:to(screenOpacity, { value = 1 }, 1, {
                    ease = anim.ease.outCubic,
                    onComplete = function()
                        transitioning = false
                        dirty = true
                    end
                })
            end
        })
        dirty = true
    end

    -- Advance animations at a fixed timestep to avoid redrawing "too fast" for the display.
    if type(dt) == "number" and dt > 0 then
        acc = acc + dt
        if acc > 0.25 then acc = 0.25 end -- prevent spiral-of-death on long frames

        local changed = false
        while acc >= STEP do
            if a:update(STEP) then changed = true end
            acc = acc - STEP
        end
        if changed then dirty = true end
    end
end

function draw()
    if not dirty then return end
    dirty = false

    if screen == "welcome" then
        drawWelcome()
        buf.present()
        return
    end

    drawTesting()
    buf.present()
end