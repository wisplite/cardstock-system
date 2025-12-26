-- syslib/anim.lua
--
-- Small animation helper built around time-based tweens driven by `dt`.
--
-- Usage:
--   local anim = require("anim")
--   local a = anim.new()
--   local state = { x = 0, alpha = 0 }
--
--   a:to(state, { x = 100, alpha = 1 }, 0.25, { ease = anim.ease.outCubic })
--   a:after(0.25, function() print("done") end)
--
-- In your tick(dt):
--   local changed = a:update(dt)
--   if changed then dirty = true end
--
-- Notes:
-- - Tweens interpolate numeric fields only.
-- - `update(dt)` returns true if anything advanced/ran this frame (useful for dirty redraw).

local anim = {}

local function clamp01(x)
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

anim.ease = {}
anim.ease.linear = function(t) return t end
anim.ease.inQuad = function(t) return t * t end
anim.ease.outQuad = function(t) return 1 - (1 - t) * (1 - t) end
anim.ease.inOutQuad = function(t)
    if t < 0.5 then return 2 * t * t end
    return 1 - ((-2 * t + 2) ^ 2) / 2
end
anim.ease.inCubic = function(t) return t * t * t end
anim.ease.outCubic = function(t) return 1 - (1 - t) ^ 3 end
anim.ease.inOutCubic = function(t)
    if t < 0.5 then return 4 * t * t * t end
    return 1 - ((-2 * t + 2) ^ 3) / 2
end
anim.ease.outBack = function(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local Tween = {}
Tween.__index = Tween

function Tween:cancel()
    self._cancelled = true
end

function Tween:pause()
    self._paused = true
end

function Tween:resume()
    self._paused = false
end

function Tween:isDone()
    return self._done or self._cancelled
end

local Animator = {}
Animator.__index = Animator

function anim.new()
    return setmetatable({
        _tweens = {},
        _timers = {}, -- { t=remaining, fn=function, cancelled=bool }
    }, Animator)
end

local function snapshotFrom(subject, goal)
    local from = {}
    for k, _ in pairs(goal) do
        local v = subject[k]
        assert(type(v) == "number", ("anim: subject[%s] must be a number (got %s)"):format(tostring(k), type(v)))
        from[k] = v
    end
    return from
end

-- Tween numeric fields on `subject` to match `goal` over `duration` seconds.
-- opts:
--   ease (fn): easing function taking t in [0,1]
--   delay (number): seconds to wait before starting
--   loop (number): how many extra times to repeat after the first run (0 = no repeat, -1 = infinite)
--   yoyo (bool): if true, swap from/to each loop
--   onStart/onUpdate/onComplete (fn): callbacks
function Animator:to(subject, goal, duration, opts)
    assert(type(subject) == "table", "anim:to subject must be a table")
    assert(type(goal) == "table", "anim:to goal must be a table")
    assert(type(duration) == "number" and duration >= 0, "anim:to duration must be a non-negative number")
    opts = opts or {}

    local tw = setmetatable({
        subject = subject,
        goal = goal,
        from = snapshotFrom(subject, goal),
        duration = duration,
        ease = opts.ease or anim.ease.linear,
        delay = opts.delay or 0,
        loop = opts.loop or 0,
        yoyo = opts.yoyo or false,
        onStart = opts.onStart,
        onUpdate = opts.onUpdate,
        onComplete = opts.onComplete,
        _elapsed = 0,
        _started = false,
        _done = false,
        _cancelled = false,
        _paused = false,
    }, Tween)

    table.insert(self._tweens, tw)
    return tw
end

-- Schedule a callback after `delay` seconds.
function Animator:after(delay, fn)
    assert(type(delay) == "number" and delay >= 0, "anim:after delay must be a non-negative number")
    assert(type(fn) == "function", "anim:after fn must be a function")
    local t = { t = delay, fn = fn, cancelled = false }
    table.insert(self._timers, t)
    return {
        cancel = function() t.cancelled = true end
    }
end

function Animator:clear()
    self._tweens = {}
    self._timers = {}
end

function Animator:isActive()
    return (#self._tweens > 0) or (#self._timers > 0)
end

-- Advances animations by dt seconds.
-- Returns true if anything advanced (properties changed or callbacks executed).
function Animator:update(dt)
    if type(dt) ~= "number" or dt <= 0 then
        return false
    end

    local changed = false

    -- Timers
    for i = #self._timers, 1, -1 do
        local t = self._timers[i]
        if t.cancelled then
            table.remove(self._timers, i)
        else
            t.t = t.t - dt
            if t.t <= 0 then
                -- run once
                t.cancelled = true
                table.remove(self._timers, i)
                t.fn()
                changed = true
            end
        end
    end

    -- Tweens
    for i = #self._tweens, 1, -1 do
        local tw = self._tweens[i]

        if tw._cancelled then
            table.remove(self._tweens, i)
        elseif tw._paused then
            -- no-op
        else
            if tw.delay > 0 then
                tw.delay = tw.delay - dt
                if tw.delay <= 0 then
                    -- start this frame (carry leftover dt)
                    local carry = -tw.delay
                    tw.delay = 0
                    if not tw._started then
                        tw._started = true
                        if tw.onStart then tw.onStart(tw.subject) end
                        changed = true
                    end
                    if carry > 0 then
                        tw._elapsed = tw._elapsed + carry
                    end
                end
            else
                if not tw._started then
                    tw._started = true
                    if tw.onStart then tw.onStart(tw.subject) end
                    changed = true
                end
                tw._elapsed = tw._elapsed + dt
            end

            if tw._started then
                local t = (tw.duration == 0) and 1 or (tw._elapsed / tw.duration)
                local p = clamp01(t)
                local e = tw.ease(p)

                for k, toV in pairs(tw.goal) do
                    local fromV = tw.from[k]
                    tw.subject[k] = lerp(fromV, toV, e)
                end

                if tw.onUpdate then tw.onUpdate(tw.subject, p) end
                changed = true

                if t >= 1 then
                    -- finalize exact goal
                    for k, toV in pairs(tw.goal) do
                        tw.subject[k] = toV
                    end

                    if tw.loop == 0 then
                        tw._done = true
                        table.remove(self._tweens, i)
                        if tw.onComplete then tw.onComplete(tw.subject) end
                        changed = true
                    else
                        if tw.loop > 0 then tw.loop = tw.loop - 1 end

                        -- Reset for next loop
                        tw._elapsed = 0
                        tw._started = false

                        if tw.yoyo then
                            -- swap from/goal
                            local newGoal = {}
                            for k, _ in pairs(tw.goal) do
                                newGoal[k] = tw.from[k]
                            end
                            tw.from = snapshotFrom(tw.subject, newGoal)
                            tw.goal = newGoal
                        else
                            tw.from = snapshotFrom(tw.subject, tw.goal)
                        end
                    end
                end
            end
        end
    end

    return changed
end

return anim


