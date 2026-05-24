-- TitleScene — Minimal boot scene for hakcd-v4 foundation.
-- Draws "HAKCD" centered on a white background. Replaced by real title in Phase 1.

TitleScene = {}
class("TitleScene").extends(NobleScene)
local scene = TitleScene

scene.backgroundColor = Graphics.kColorWhite

function scene:init()
    scene.super.init(self)
end

function scene:enter()
    scene.super.enter(self)
end

function scene:drawBackground()
    scene.super.drawBackground(self)

    Graphics.setColor(Graphics.kColorBlack)
    Graphics.setImageDrawMode(Graphics.kDrawModeFillBlack)

    local label = "HAKCD"
    local font = Graphics.getSystemFont()
    local w = font:getTextWidth(label)
    local h = font:getHeight()
    local screenW, screenH = 400, 240
    Graphics.drawText(label, (screenW - w) // 2, (screenH - h) // 2)
end
