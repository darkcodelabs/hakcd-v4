-- scenes/ModemScene.lua
-- War-dialer animation accessed from bedroom 'modem' hotspot.
-- ATDT cycle: dial → ringing → CARRIER 33600 → "deadline bbs node 2 online"
-- A advances. B back to bedroom.

import 'libraries/noble/Noble'

ModemScene = {}
class('ModemScene').extends(NobleScene)

ModemScene.backgroundColor = playdate.graphics.kColorBlack

local gfx = playdate.graphics

local STEPS = {
    { txt = "ATZ",            ms = 250,  sfx = nil },
    { txt = "OK",              ms = 350,  sfx = nil },
    { txt = "ATDT 555-1337",   ms = 600,  sfx = 'tyson_digit_commit' },
    { txt = "...",             ms = 600,  sfx = nil },
    { txt = "RING",            ms = 800,  sfx = 'lockpick_tension_warn' },
    { txt = "RING",            ms = 800,  sfx = 'lockpick_tension_warn' },
    { txt = "RING",            ms = 800,  sfx = 'lockpick_tension_warn' },
    { txt = "CARRIER 33600",   ms = 700,  sfx = 'lockpick_pin_set' },
    { txt = "PROTOCOL: LAPM",  ms = 500,  sfx = nil },
    { txt = "COMPRESSION: V.42bis", ms = 500, sfx = nil },
    { txt = "CONNECT 33600/V42",    ms = 700, sfx = 'lockpick_open' },
    { txt = "",                       ms = 200,  sfx = nil },
    { txt = "DEADLINE BBS NODE 2",    ms = 800, sfx = nil },
    { txt = "you are online.",        ms = 1500, sfx = nil },
}

function ModemScene:init()
    ModemScene.super.init(self)
end

function ModemScene:enter(previousScene)
    ModemScene.super.enter(self, previousScene)
    self._previousScene = previousScene
    self.stepIdx = 1
    self.stepStartMs = playdate.getCurrentTimeMilliseconds()
    self.shown = {}
    self:_emitStep()
end

function ModemScene:_emitStep()
    local s = STEPS[self.stepIdx]
    if not s then return end
    table.insert(self.shown, s.txt)
    if s.sfx and sound_manifest and sound_manifest.play_sfx then
        sound_manifest.play_sfx(s.sfx)
    end
end

function ModemScene:update()
    ModemScene.super.update(self)
    local now = playdate.getCurrentTimeMilliseconds()
    local s = STEPS[self.stepIdx]
    if s and now - self.stepStartMs >= s.ms then
        self.stepIdx = self.stepIdx + 1
        self.stepStartMs = now
        if STEPS[self.stepIdx] then self:_emitStep() end
    end

    if playdate.buttonJustPressed(playdate.kButtonA) then
        -- Skip / advance through tail end
        if self.stepIdx > #STEPS then
            Noble.transition(BedroomScene)
        end
    end
    if playdate.buttonJustPressed(playdate.kButtonB) then
        Noble.transition(BedroomScene)
    end
end

function ModemScene:drawBackground()
    gfx.clear(gfx.kColorBlack)
end

function ModemScene:drawForeground()
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    -- Header
    gfx.drawText('USR Sportster Flash 56k', 16, 8)
    gfx.drawLine(16, 22, 384, 22)
    -- Output log
    local y = 30
    local visible = math.max(0, #self.shown - 12)
    for i = visible + 1, #self.shown do
        gfx.drawText(self.shown[i] or '', 16, y)
        y = y + 14
    end

    -- Status strip
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.fillRect(0, 220, 400, 20)
    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
    local status
    if self.stepIdx > #STEPS then
        status = '[A] disconnect    [B] hangup'
    else
        status = string.format('dialing %d / %d', self.stepIdx, #STEPS)
    end
    gfx.drawTextAligned(status, 200, 224, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

_G.ModemScene = ModemScene
return ModemScene
