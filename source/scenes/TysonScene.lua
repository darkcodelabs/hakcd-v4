-- TysonScene — Mike Tyson's Punch-Out!! NES master unlock code (007-373-5963).
-- Port of v0.0.3 runtime/concepts/pwnglove_tyson.lua wrapped in NobleScene.
-- Logic preserved verbatim:
--   * 11 slots (9 digits + dashes at positions 4 and 8)
--   * Crank rotates current digit 0..9 (36 deg per step)
--   * A commits + advances cursor, auto-skipping dashes
--   * Full match -> Progression.set_flag(canon.state_flags.tyson_unlock.id,true) + overlay 3s before exit
--   * B abandons
--
-- Visual upgrade vs v0.0.3:
--   * Black background with GFXP gray-50 accent on digit slot fills
--   * "TYSON MODE" win banner renders with GFXP random-noise overlay flicker
--
-- Save: routes through Progression.set_flag(canon.state_flags.tyson_unlock.id, true)
-- (Phase 12 v0.1.24 — no direct Noble.GameData access; no bare flag strings).
-- SFX (Agent 5 / CONTENT, may not exist yet):
--   tyson_digit_select, tyson_digit_commit, tyson_winner

TysonScene = {}
class("TysonScene").extends(NobleScene)
local scene = TysonScene
local gfx <const> = playdate.graphics
local gfxp <const> = GFXP

scene.backgroundColor = Graphics.kColorBlack

local CODE = '007-373-5963'
local SCREEN_W, SCREEN_H = 400, 240

local function sfx(name)
    if _G.sound_manifest and _G.sound_manifest.play_sfx then
        _G.sound_manifest.play_sfx(name)
    end
end

-- ============================================================
-- LIFECYCLE
-- ============================================================
function scene:init(__sceneProperties)
    scene.super.init(self)
    __sceneProperties = __sceneProperties or {}
    self._return_scene = __sceneProperties.return_scene
    self._target = __sceneProperties.code or CODE
end

function scene:enter()
    scene.super.enter(self)

    if _G.sound_manifest and _G.sound_manifest.start_scene_music then
        _G.sound_manifest.start_scene_music('TysonScene')
    end

    self.target = self._target
    self.slots = {}
    for i = 1, #self.target do
        self.slots[i] = (self.target:sub(i, i) == '-') and '-' or '?'
    end
    self.cursor = 1
    self.crank_accum = 0
    self.current_digit = 0
    self.state = 'in_progress'
    self.overlay_until_ms = 0
    self._exit_at_ms = 0
    self._noise_tick = 0

    -- already_granted check — canon-guarded read via Progression.get_flag.
    -- canon.state_flags.tyson_unlock.id is the only legal indirection here;
    -- never reference the bare flag id as a literal string in scene code.
    local granted = Progression.get_flag(canon.state_flags.tyson_unlock.id) == true
    if granted then
        self.state = 'already_granted'
        self.overlay_until_ms = playdate.getCurrentTimeMilliseconds() + 2500
        self._exit_at_ms = self.overlay_until_ms
    else
        while self.target:sub(self.cursor, self.cursor) == '-' do
            self.cursor = self.cursor + 1
        end
    end
end

-- ============================================================
-- UPDATE
-- ============================================================
function scene:update()
    scene.super.update(self)
    self._noise_tick = self._noise_tick + 1

    if self.state == 'already_granted' then
        if playdate.getCurrentTimeMilliseconds() > self.overlay_until_ms then
            self:_exit_back()
        end
        return
    end
    if self.state == 'unlocked' then
        if playdate.getCurrentTimeMilliseconds() > self.overlay_until_ms then
            self:_exit_back()
        end
        return
    end
    if self.state == 'failed' then
        if self._exit_at_ms > 0 and playdate.getCurrentTimeMilliseconds() > self._exit_at_ms then
            self:_exit_back()
        end
        return
    end
end

function scene:_exit_back()
    if self._return_scene then
        -- Phase 11: SceneRouter.transition is the class-pass-through variant;
        -- _return_scene is the class handed in via PlaygroundScene's launch
        -- args, not a canon scene_id.
        SceneRouter.transition(self._return_scene)
    end
end

-- ============================================================
-- LOGIC (preserved verbatim from v0.0.3)
-- ============================================================
function scene:_commit_digit()
    if self.state ~= 'in_progress' then return end
    self.slots[self.cursor] = tostring(self.current_digit)
    sfx('tyson_digit_commit')
    repeat
        self.cursor = self.cursor + 1
    until self.cursor > #self.target or self.target:sub(self.cursor, self.cursor) ~= '-'

    if self.cursor > #self.target then
        local entered = table.concat(self.slots, '')
        if entered == self.target then
            self.state = 'unlocked'
            self.overlay_until_ms = playdate.getCurrentTimeMilliseconds() + 3000
            -- Canon-guarded write — Progression.set_flag HARD-asserts that
            -- canon.state_flags.tyson_unlock.id is in canon.state_flags, so a
            -- canon-drift typo here crashes loud on sideload (Phase 8 guard).
            Progression.set_flag(canon.state_flags.tyson_unlock.id, true)
            sfx('tyson_winner')
        else
            self.state = 'failed'
            self._exit_at_ms = playdate.getCurrentTimeMilliseconds() + 2200
            -- Reset slots so the failed display starts clean (matches v0.0.3).
            self.cursor = 1
            for i = 1, #self.target do
                self.slots[i] = (self.target:sub(i, i) == '-') and '-' or '?'
            end
        end
    end
    self.current_digit = 0
    self.crank_accum = 0
end

function scene:_crank_step(change_deg)
    if self.state ~= 'in_progress' then return end
    self.crank_accum = self.crank_accum + (change_deg or 0)
    while self.crank_accum >= 36 do
        self.crank_accum = self.crank_accum - 36
        self.current_digit = (self.current_digit + 1) % 10
        sfx('tyson_digit_select')
    end
    while self.crank_accum <= -36 do
        self.crank_accum = self.crank_accum + 36
        self.current_digit = (self.current_digit - 1) % 10
        if self.current_digit < 0 then self.current_digit = self.current_digit + 10 end
        sfx('tyson_digit_select')
    end
end

-- ============================================================
-- INPUT
-- ============================================================
scene.inputHandler = {
    AButtonDown = function()
        local s = Noble.currentScene()
        if s and s._commit_digit then s:_commit_digit() end
    end,
    BButtonDown = function()
        local s = Noble.currentScene()
        if s and s.state == 'in_progress' then
            s.state = 'failed'
            s._exit_at_ms = playdate.getCurrentTimeMilliseconds() + 600
        end
    end,
    cranked = function(change, _accel)
        local s = Noble.currentScene()
        if s and s._crank_step then s:_crank_step(change) end
    end
}

-- ============================================================
-- DRAW
-- ============================================================
function scene:drawBackground()
    scene.super.drawBackground(self)

    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)

    gfx.drawTextAligned("MIKE TYSON'S PUNCH-OUT!!", 200, 24, kTextAlignment.center)
    gfx.drawTextAligned('enter the code', 200, 42, kTextAlignment.center)

    -- 11 slots horizontal
    local slot_w = 24
    local total_w = #self.target * slot_w
    local start_x = (SCREEN_W - total_w) / 2
    for i = 1, #self.target do
        local x = start_x + (i - 1) * slot_w
        local y = 90
        -- GFXP fill behind committed/dashed slots for visual accent.
        local ch = self.slots[i] or '?'
        if ch ~= '?' then
            gfxp.set('gray-3')
            gfx.fillRect(x, y, slot_w - 4, 30)
            gfxp.set('white')
        end
        gfx.drawRect(x, y, slot_w - 4, 30)
        gfx.drawTextAligned(ch, x + (slot_w - 4) / 2, y + 8, kTextAlignment.center)
        if i == self.cursor and self.state == 'in_progress' then
            gfx.drawTextAligned(tostring(self.current_digit),
                x + (slot_w - 4) / 2, y - 18, kTextAlignment.center)
            local cx = x + (slot_w - 4) / 2
            gfx.fillTriangle(cx - 4, y - 2, cx + 4, y - 2, cx, y + 4)
        end
    end

    gfx.drawTextAligned('[CRANK] digit  [A] commit  [B] cancel',
        200, 160, kTextAlignment.center)

    if self.state == 'unlocked' then
        -- Flicker banner with random-noise GFXP overlay every ~4 frames.
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0, 90, SCREEN_W, 60)
        if (self._noise_tick % 4) < 2 then
            gfxp.set('dot-5')
            gfx.fillRect(0, 90, SCREEN_W, 60)
            gfxp.set('white')
        end
        gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
        gfx.drawTextAligned('* TYSON MODE *', 200, 102, kTextAlignment.center)
        gfx.drawTextAligned('ALL PWNGLOVE POWERS UNLOCKED', 200, 124, kTextAlignment.center)
        gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    elseif self.state == 'already_granted' then
        gfx.drawTextAligned('ALREADY GRANTED -- 1987',
            200, 200, kTextAlignment.center)
    elseif self.state == 'failed' then
        gfx.drawTextAligned("That's not it. Try again.",
            200, 200, kTextAlignment.center)
    end

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end
