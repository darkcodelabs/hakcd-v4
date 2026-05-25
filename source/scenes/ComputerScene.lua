-- scenes/ComputerScene.lua
-- DEADLINE BBS terminal accessed from bedroom hotspot 'computer'.
-- Scrolling boot text + login prompt. A advances pages. B exits to bedroom.

import 'libraries/noble/Noble'
import 'libraries/gfxp/gfxp'

ComputerScene = {}
class('ComputerScene').extends(NobleScene)

ComputerScene.backgroundColor = playdate.graphics.kColorBlack

local gfx = playdate.graphics

-- Each page is a list of lines, drawn one char at a time at TYPEWRITER_RATE_MS per char.
local PAGES = {
    {
        "AT&FE0V1X1S0=0",
        "OK",
        "",
        "ATDT 555-1337",
        "RING",
        "RING",
        "CONNECT 33600",
        "",
        "DEADLINE BBS",
        "node 2 of 2",
        "",
        "user: _"
    },
    {
        "user: newb",
        "pass: ********",
        "",
        "> WELCOME BACK newb",
        "> last login: 1998.05.23 23:47",
        "> 1 NEW MAIL FROM phractal",
        "",
        "MAIN MENU",
        "[1] message base",
        "[2] file area",
        "[3] door games",
        "[4] who's online",
        "[B] hangup"
    },
    {
        "> 4",
        "",
        "WHO'S ONLINE",
        "----------------------",
        "node 1: phractal     idle 00:02",
        "node 2: newb         active",
        "",
        "> chat phractal",
        "[C] to confirm, [B] hangup",
    }
}

local TYPEWRITER_RATE_MS = 28
local PAGE_HOLD_AFTER_TYPED_MS = 1200

function ComputerScene:init()
    ComputerScene.super.init(self)
end

function ComputerScene:enter(previousScene)
    ComputerScene.super.enter(self, previousScene)
    if _G.sound_manifest and _G.sound_manifest.start_scene_music then
        _G.sound_manifest.start_scene_music('ComputerScene')   -- aliases bedroom_loop
    end
    self._previousScene = previousScene
    self.pageIdx = 1
    self.charCount = 0
    self.totalChars = self:_pageTotalChars(1)
    self.startMs = playdate.getCurrentTimeMilliseconds()
    self.pageDoneMs = nil
    if sound_manifest and sound_manifest.play_sfx then
        sound_manifest.play_sfx('pwnglove_boot')
    end
end

function ComputerScene:_pageTotalChars(idx)
    local total = 0
    for _, line in ipairs(PAGES[idx] or {}) do total = total + #line end
    return total
end

function ComputerScene:update()
    ComputerScene.super.update(self)
    if not PAGES[self.pageIdx] then return end

    local elapsed = playdate.getCurrentTimeMilliseconds() - self.startMs
    self.charCount = math.min(self.totalChars, math.floor(elapsed / TYPEWRITER_RATE_MS))

    if self.charCount >= self.totalChars and not self.pageDoneMs then
        self.pageDoneMs = playdate.getCurrentTimeMilliseconds()
    end

    -- A press advances pages (when current page typed); also auto-advance after hold
    local now = playdate.getCurrentTimeMilliseconds()
    local autoAdvance = self.pageDoneMs
        and (now - self.pageDoneMs) > PAGE_HOLD_AFTER_TYPED_MS
        and self.pageIdx < #PAGES
        and playdate.buttonJustPressed(playdate.kButtonA)
    local explicitAdvance = self.pageDoneMs
        and playdate.buttonJustPressed(playdate.kButtonA)
        and self.pageIdx < #PAGES

    if explicitAdvance or autoAdvance then
        self.pageIdx = self.pageIdx + 1
        self.charCount = 0
        self.totalChars = self:_pageTotalChars(self.pageIdx)
        self.startMs = now
        self.pageDoneMs = nil
        if sound_manifest and sound_manifest.play_sfx then
            sound_manifest.play_sfx('tyson_digit_select')
        end
    end

    if playdate.buttonJustPressed(playdate.kButtonB) then
        Noble.transition(BedroomScene)
    end
end

function ComputerScene:drawBackground()
    gfx.clear(gfx.kColorBlack)
end

function ComputerScene:drawForeground()
    local lines = PAGES[self.pageIdx] or {}
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    -- Reveal char-by-char across the whole page (typewriter)
    local remaining = self.charCount
    local y = 20
    for _, line in ipairs(lines) do
        if remaining <= 0 then break end
        local visible = (remaining >= #line) and line or line:sub(1, remaining)
        gfx.drawText(visible, 16, y)
        y = y + 16
        remaining = remaining - #line
    end

    -- Status strip bottom
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.fillRect(0, 220, 400, 20)
    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
    local status
    if self.pageDoneMs and self.pageIdx < #PAGES then
        status = '[A] next page    [B] hangup'
    elseif self.pageDoneMs then
        status = '[B] hangup'
    else
        status = 'DEADLINE BBS   node 2/2   33600'
    end
    gfx.drawTextAligned(status, 200, 224, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

_G.ComputerScene = ComputerScene
return ComputerScene
