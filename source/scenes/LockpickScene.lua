-- LockpickScene — 5-PIN STANDARD lockpick minigame.
-- Port of v0.0.3 runtime/concepts/pwnglove_lockpick.lua wrapped in NobleScene.
-- State machine logic (binding-zone math, tension band, 3 attempts, 60s
-- timer, fail flash) is preserved verbatim. Only the I/O surface changed:
--   * Crank input arrives via NobleScene input handler instead of an outer
--     `instance:update(dt, crank_change)` call.
--   * GFXP dithered fills replace the raw `gfx.setDitherPattern` calls on
--     the tension meter for nicer 1-bit appearance.
--   * Win/lose calls `Noble.transition(previousScene)` to return to the
--     scene that pushed us (Bedroom or Playground).
--
-- Visual reference: /home/hakcer/projects/23studios/docs/lockpickmini.png
-- SFX names (Agent 5 / CONTENT — may not exist yet):
--   lockpick_pin_click_1..4, lockpick_pin_set, lockpick_snap,
--   lockpick_tension_warn, lockpick_open

LockpickScene = {}
class("LockpickScene").extends(NobleScene)
local scene = LockpickScene
local gfx <const> = playdate.graphics
local gfxp <const> = GFXP

scene.backgroundColor = Graphics.kColorWhite

-- ============================================================
-- LAYOUT CONSTANTS (400x240 Playdate display)
-- ============================================================
local SCREEN_W, SCREEN_H = 400, 240
local TOP_BAR_Y, TOP_BAR_H = 0, 24
local CONTROLS_Y, CONTROLS_H = 160, 16
local DIALOG_Y, DIALOG_H = 176, 64

local LOCK_X, LOCK_Y = 80, 48
local LOCK_W, LOCK_H = 240, 100
local PIN_XS = { 115, 155, 195, 235, 275 }
local PIN_TOP, PIN_BOTTOM = 62, 110
local UNLOCK_ZONE_Y = 122

local COMPASS_CX, COMPASS_CY, COMPASS_R = 200, 36, 11
local BINDING_TEXT_X, BINDING_TEXT_Y = 250, 30

local TENSION_X, TENSION_Y, TENSION_W, TENSION_H = 360, 30, 22, 120

-- ============================================================
-- HELPERS
-- ============================================================
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function rand_pin_angle(binding_lo, binding_hi)
    local center = math.random(0, 359)
    return { center = center, lo = binding_lo, hi = binding_hi }
end

local function aim_in_binding(aim_deg, pin)
    local center = pin.angle.center
    local half = (pin.angle.hi - pin.angle.lo) / 2
    local delta = math.abs(((aim_deg - center + 180) % 360) - 180)
    return delta <= half
end

-- SFX dispatch — silent if Agent 5's sound_manifest hasn't loaded.
local function sfx(name)
    if _G.sound_manifest and _G.sound_manifest.play_sfx then
        _G.sound_manifest.play_sfx(name)
    end
end

-- ============================================================
-- DRAW PRIMITIVES
-- ============================================================
local function draw_box(x, y, w, h)
    gfx.drawRect(x, y, w, h)
    gfx.drawRect(x + 1, y + 1, w - 2, h - 2)
end

local function draw_pill(x, y, w, h, text)
    gfx.drawRoundRect(x, y, w, h, 3)
    gfx.drawTextInRect(text, x + 4, y + 1, w - 8, h - 2, nil, '', kTextAlignment.center)
end

local function draw_hourglass(x, y)
    gfx.drawLine(x, y, x + 8, y)
    gfx.drawLine(x, y + 10, x + 8, y + 10)
    gfx.drawLine(x, y, x + 4, y + 5)
    gfx.drawLine(x + 8, y, x + 4, y + 5)
    gfx.drawLine(x, y + 10, x + 4, y + 5)
    gfx.drawLine(x + 8, y + 10, x + 4, y + 5)
end

local function draw_compass(cx, cy, r, aim_deg)
    gfx.drawCircleAtPoint(cx, cy, r)
    gfx.drawTextAligned('N', cx, cy - r - 8, kTextAlignment.center)
    gfx.drawTextAligned('S', cx, cy + r - 2, kTextAlignment.center)
    gfx.drawText('W', cx - r - 7, cy - 6)
    gfx.drawText('E', cx + r + 1, cy - 6)
    local rad = math.rad(aim_deg - 90)
    local tip_x = cx + math.cos(rad) * (r - 2)
    local tip_y = cy + math.sin(rad) * (r - 2)
    local back_a = rad + math.pi
    local back_x1 = cx + math.cos(back_a + 0.3) * 5
    local back_y1 = cy + math.sin(back_a + 0.3) * 5
    local back_x2 = cx + math.cos(back_a - 0.3) * 5
    local back_y2 = cy + math.sin(back_a - 0.3) * 5
    gfx.fillTriangle(tip_x, tip_y, back_x1, back_y1, back_x2, back_y2)
end

local function draw_tension_meter(x, y, w, h, tension)
    gfx.drawRect(x, y, w, h)
    local stop_h = math.floor(h * 0.20)
    local safe_h = math.floor(h * 0.55)
    local care_h = h - stop_h - safe_h
    -- STOP zone (top) — GFXP darker pattern
    gfxp.set('darkgray')
    gfx.fillRect(x + 1, y + 1, w - 2, stop_h - 1)
    -- CARE zone (middle) — GFXP mid pattern
    gfxp.set('gray')
    gfx.fillRect(x + 1, y + stop_h, w - 2, care_h)
    -- SAFE zone (bottom) — leave white
    gfx.setColor(gfx.kColorBlack)
    gfxp.set('white')   -- reset pattern back to solid

    gfx.drawText('STOP', x - 30, y + math.floor(stop_h / 2) - 4)
    gfx.drawText('CARE', x - 30, y + stop_h + math.floor(care_h / 2) - 4)
    gfx.drawText('SAFE', x - 30, y + stop_h + care_h + math.floor(safe_h / 2) - 4)

    local marker_y = y + h - math.floor(tension * h)
    marker_y = clamp(marker_y, y + 2, y + h - 2)
    gfx.fillTriangle(x + w + 4, marker_y, x + w + 12, marker_y - 4, x + w + 12, marker_y + 4)
end

-- ============================================================
-- LIFECYCLE
-- ============================================================
function scene:init(__sceneProperties)
    scene.super.init(self)
    __sceneProperties = __sceneProperties or {}
    self._return_scene = __sceneProperties.return_scene  -- class reference, optional
    self._pin_count = __sceneProperties.pin_count or 5
    self._attempts = __sceneProperties.attempts or 3
    self._time_limit_sec = __sceneProperties.time_limit_sec or 60
    self._binding_zone_deg = __sceneProperties.binding_zone_deg or { 45, 90 }

    self._lock_img = gfx.image.new('images/ui/lockpick_body')
    self._newb_img = gfx.image.new('images/portraits/newb')
end

function scene:enter()
    scene.super.enter(self)
    -- LockpickScene is silent during the minigame — only SFX, no music bed.
    if _G.sound_manifest and _G.sound_manifest.start_scene_music then
        _G.sound_manifest.start_scene_music('LockpickScene')   -- maps to nil = stops
    end
    self:_reset_state()
end

function scene:_reset_state()
    self.start_ms = playdate.getCurrentTimeMilliseconds()
    self.aim_deg = 0
    self.tension = 0
    self.pins = {}
    for i = 1, self._pin_count do
        self.pins[i] = {
            angle = rand_pin_angle(self._binding_zone_deg[1], self._binding_zone_deg[2]),
            set = false,
            failure_flash = 0
        }
    end
    self.current_pin = 1
    self.attempts_left = self._attempts
    self.points = 0
    self.state = 'in_progress'  -- 'in_progress' | 'open' | 'failed'
    self.dialog_text = nil
    self.dialog_until_ms = 0
    self._exit_at_ms = 0  -- delay before bouncing back so player sees outcome
end

function scene:_set_dialog(text, hold_ms)
    self.dialog_text = text
    self.dialog_until_ms = playdate.getCurrentTimeMilliseconds() + (hold_ms or 2200)
end

function scene:_time_left()
    local elapsed_ms = playdate.getCurrentTimeMilliseconds() - self.start_ms
    return math.max(0, self._time_limit_sec - math.floor(elapsed_ms / 1000))
end

-- ============================================================
-- UPDATE — runs every frame
-- ============================================================
function scene:update()
    scene.super.update(self)

    if self.state == 'in_progress' then
        -- Tension naturally bleeds off (per-frame; v0.0.3 also did this per-tick).
        self.tension = math.max(0, self.tension - 0.0008)

        -- Time-out check.
        if self:_time_left() <= 0 then
            self:_fail('Time up. Snapped the wrench.', 2500)
        end

        -- Decay failure flash per pin.
        for _, p in ipairs(self.pins) do
            if p.failure_flash > 0 then p.failure_flash = p.failure_flash - 1 end
        end
    else
        -- Once done, hold the result on screen for the dialog duration, then
        -- transition back to whoever launched us.
        if self._exit_at_ms > 0 and playdate.getCurrentTimeMilliseconds() >= self._exit_at_ms then
            self._exit_at_ms = 0
            local target = self._return_scene
            if target then
                Noble.transition(target)
            end
        end
    end
end

-- ============================================================
-- LOGIC (preserved verbatim from v0.0.3)
-- ============================================================
function scene:_try_lock_current_pin()
    if self.state ~= 'in_progress' then return end
    local pin = self.pins[self.current_pin]
    if not pin or pin.set then return end

    self.tension = clamp(self.tension + 0.15, 0, 1.0)

    if aim_in_binding(self.aim_deg, pin) then
        pin.set = true
        self.points = self.points + 100
        -- Per-pin newb dialog reactions — preserved verbatim.
        local reactions = {
            [1] = "Easy. Standard pin.",
            [2] = "Pin two. Crank slow.",
            [3] = "Pin three. Steady on the crank. Almost there.",
            [4] = "Pin four. Tension up.",
            [5] = "Last pin. Don't blow it."
        }
        self:_set_dialog(reactions[self.current_pin] or "Pin set.")
        sfx('lockpick_pin_set')
        -- variant click: manifest randomly chooses one of the 4 click samples
        sfx('lockpick_pin_click')

        self.current_pin = self.current_pin + 1
        if self.current_pin > self._pin_count then
            self.state = 'open'
            self:_set_dialog("Clean. Knuckleheads style.", 3000)
            self._exit_at_ms = playdate.getCurrentTimeMilliseconds() + 2500
            sfx('lockpick_open')
        end
    else
        -- Wrong angle: snap. Reset all pins, decrement attempt.
        pin.failure_flash = 18
        for _, p in ipairs(self.pins) do p.set = false end
        self.current_pin = 1
        self.attempts_left = self.attempts_left - 1
        self.tension = 0
        self:_set_dialog("Snapped. Try again.")
        sfx('lockpick_snap')
        if self.attempts_left <= 0 then
            self:_fail("Snapped the tension wrench. Try again.", 3500)
        end
    end

    -- Over-tension instant fail check.
    if self.tension >= 1.0 and self.state == 'in_progress' then
        self.attempts_left = self.attempts_left - 1
        for _, p in ipairs(self.pins) do p.set = false end
        self.current_pin = 1
        self.tension = 0
        self:_set_dialog("Easy. Easy. Don't snap it.")
        sfx('lockpick_tension_warn')
        if self.attempts_left <= 0 then
            self:_fail("Too much torque. Try again.", 3500)
        end
    end
end

function scene:_fail(msg, hold_ms)
    self.state = 'failed'
    self:_set_dialog(msg, hold_ms or 2500)
    self._exit_at_ms = playdate.getCurrentTimeMilliseconds() + (hold_ms or 2500)
end

-- ============================================================
-- INPUT
-- ============================================================
scene.inputHandler = {
    AButtonDown = function()
        local s = Noble.currentScene()
        if s and s._try_lock_current_pin then s:_try_lock_current_pin() end
    end,
    BButtonDown = function()
        local s = Noble.currentScene()
        if s and s.state == 'in_progress' then
            s:_set_dialog("Abandoned.", 1500)
            s.state = 'failed'
            s._exit_at_ms = playdate.getCurrentTimeMilliseconds() + 800
        end
    end,
    cranked = function(change, _accel)
        local s = Noble.currentScene()
        if s and s.state == 'in_progress' and change and change ~= 0 then
            s.aim_deg = (s.aim_deg + change) % 360
            if s.aim_deg < 0 then s.aim_deg = s.aim_deg + 360 end
        end
    end
}

-- ============================================================
-- DRAW
-- ============================================================
function scene:drawBackground()
    scene.super.drawBackground(self)

    gfx.setColor(gfx.kColorBlack)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)

    -- ------------------ TOP BAR ------------------
    draw_box(0, 0, SCREEN_W, TOP_BAR_H)
    gfx.drawText('PUZZLE: 5-PIN STANDARD', 6, 2)
    gfx.drawText(string.format('ATTEMPT %d / 3',
        math.max(1, 4 - self.attempts_left)), 6, 12)
    draw_pill(160, 2, 80, 10, string.format('%d POINTS', self.points))
    draw_hourglass(250, 4)
    local tl = self:_time_left()
    gfx.drawText(string.format('%d:%02d', math.floor(tl / 60), tl % 60), 264, 4)
    local right_pill_text =
        (self.state == 'open')   and 'LOCK OPEN' or
        (self.state == 'failed') and 'FAILED'    or
        'PUZZLE IN PROGRESS'
    draw_pill(290, 2, 108, 10, right_pill_text)

    -- ------------------ MID BAND ------------------
    draw_compass(COMPASS_CX, COMPASS_CY, COMPASS_R, self.aim_deg)
    draw_pill(BINDING_TEXT_X, BINDING_TEXT_Y, 100, 12,
        string.format('BINDING ZONE %d-%d', self._binding_zone_deg[1], self._binding_zone_deg[2]))

    if self._lock_img then
        self._lock_img:draw(LOCK_X, LOCK_Y)
    else
        gfx.drawRect(LOCK_X, LOCK_Y, LOCK_W, LOCK_H)
        for _, px in ipairs(PIN_XS) do
            gfx.fillRect(px - 6, PIN_TOP - 4, 12, PIN_BOTTOM - PIN_TOP + 8)
        end
    end

    for i, pin in ipairs(self.pins) do
        local px = PIN_XS[i]
        if pin.failure_flash > 0 then
            -- Flash with a GFXP dot-1 pattern to suggest sparks.
            gfxp.set('dot-3')
            gfx.fillRect(px - 8, PIN_TOP - 6, 16, PIN_BOTTOM - PIN_TOP + 12)
            gfxp.set('white')
        end
        if pin.set then
            gfx.fillRect(px - 4, PIN_TOP, 8, 8)
            gfx.drawText('v', px - 3, UNLOCK_ZONE_Y - 14)
        elseif i == self.current_pin then
            gfx.drawRect(px - 5, PIN_TOP, 10, 10)
            gfx.drawLine(px - 8, PIN_TOP - 4, px + 8, PIN_TOP - 4)
        end
        gfx.drawTextAligned(tostring(i), px, UNLOCK_ZONE_Y - 8, kTextAlignment.center)
    end

    gfx.drawLine(PIN_XS[1] - 10, UNLOCK_ZONE_Y + 5,
                 PIN_XS[5] + 10, UNLOCK_ZONE_Y + 5)
    gfx.drawTextAligned('UNLOCK ZONE',
        (PIN_XS[1] + PIN_XS[5]) / 2, UNLOCK_ZONE_Y + 8,
        kTextAlignment.center)

    draw_tension_meter(TENSION_X, TENSION_Y, TENSION_W, TENSION_H, self.tension)

    -- ------------------ CONTROLS BAR ------------------
    draw_box(0, CONTROLS_Y, SCREEN_W, CONTROLS_H)
    gfx.drawText('[CRANK] AIM', 8, CONTROLS_Y + 3)
    gfx.drawText('[A] LOCK PIN', 150, CONTROLS_Y + 3)
    gfx.drawText('[B] ABANDON', 290, CONTROLS_Y + 3)

    -- ------------------ DIALOG BAR ------------------
    draw_box(0, DIALOG_Y, SCREEN_W, DIALOG_H)
    gfx.drawText('newb', 6, DIALOG_Y + 2)
    gfx.drawLine(0, DIALOG_Y + 14, SCREEN_W - 56, DIALOG_Y + 14)
    if self.dialog_text then
        gfx.drawTextInRect(self.dialog_text, 6, DIALOG_Y + 18,
                           SCREEN_W - 64, DIALOG_H - 20)
    end
    gfx.drawRect(SCREEN_W - 52, DIALOG_Y + 4, 48, 56)
    if self._newb_img then
        self._newb_img:draw(SCREEN_W - 50, DIALOG_Y + 6)
    else
        gfx.drawTextAligned('newb', SCREEN_W - 28, DIALOG_Y + 28, kTextAlignment.center)
    end
end
