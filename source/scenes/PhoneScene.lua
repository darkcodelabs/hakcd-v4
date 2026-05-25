-- scenes/PhoneScene.lua
-- Mom dialog popup from bedroom 'phone' hotspot. Canonical lines from the
-- bible: mom's "phone line is mine after midnight" + "paying the bill if
-- it's over fifty" + "I CAN hear that screech." A advances. B exits.

import 'libraries/noble/Noble'

PhoneScene = {}
class('PhoneScene').extends(NobleScene)

PhoneScene.backgroundColor = playdate.graphics.kColorWhite

local gfx = playdate.graphics

local LINES = {
    "MOM: I see you up there.",
    "MOM: Phone line is mine after midnight.",
    "MOM: You're paying the bill if it's over fifty.",
    "MOM: ... and yes, I CAN hear that screech.",
    "MOM: Go to bed, hacker man.",
}

function PhoneScene:init()
    PhoneScene.super.init(self)
end

function PhoneScene:enter(previousScene)
    PhoneScene.super.enter(self, previousScene)
    self._previousScene = previousScene
    self.idx = 1
    if sound_manifest and sound_manifest.play_sfx then
        sound_manifest.play_sfx('lockpick_tension_warn')   -- phone ring placeholder
    end
end

function PhoneScene:update()
    PhoneScene.super.update(self)
    if playdate.buttonJustPressed(playdate.kButtonA) then
        self.idx = self.idx + 1
        if self.idx > #LINES then
            Noble.transition(BedroomScene)
        else
            if sound_manifest and sound_manifest.play_sfx then
                sound_manifest.play_sfx('tyson_digit_select')
            end
        end
    end
    if playdate.buttonJustPressed(playdate.kButtonB) then
        Noble.transition(BedroomScene)
    end
end

function PhoneScene:drawForeground()
    -- Faux receiver-on-screen visual: dark border with the call active glyph
    gfx.fillRect(0, 0, 400, 240)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(8, 8, 384, 224)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(8, 8, 384, 224)
    gfx.drawRect(10, 10, 380, 220)

    -- Phone receiver icon (top)
    gfx.drawText('* PHONE *', 16, 16)
    gfx.drawText('inbound: MOM (downstairs)', 16, 32)
    gfx.drawLine(16, 50, 384, 50)

    -- Current line in big-ish center area
    local line = LINES[self.idx] or ''
    gfx.drawTextInRect(line, 32, 80, 336, 100, nil, '', kTextAlignment.left)

    -- Progress + prompt strip
    gfx.fillRect(8, 200, 384, 32)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawText(string.format('%d / %d', self.idx, #LINES), 16, 208)
    gfx.drawTextAligned('[A] next   [B] hang up', 200, 208, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

_G.PhoneScene = PhoneScene
return PhoneScene
