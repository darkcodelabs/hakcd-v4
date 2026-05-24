-- SpriteTestScene — temporary boot scene for Agent 2's sprite deliverable.
--
-- Spawns a single Newb at the screen center, drives its d-pad-driven state
-- machine each frame, and renders a hint label.  Agent 4 (PORT) restores
-- TitleScene as the boot scene during scene-flow wiring.

SpriteTestScene = {}
class('SpriteTestScene').extends(NobleScene)
local scene = SpriteTestScene

scene.backgroundColor = Graphics.kColorWhite

local newb = nil

function scene:init()
    scene.super.init(self)
end

function scene:enter()
    scene.super.enter(self)
    newb = Newb(200, 120)
end

function scene:update()
    scene.super.update(self)
    if newb then
        newb:updateMovement()
    end
end

function scene:drawBackground()
    scene.super.drawBackground(self)

    Graphics.setColor(Graphics.kColorBlack)
    Graphics.setImageDrawMode(Graphics.kDrawModeFillBlack)

    local label = 'PRESS D-PAD'
    local font = Graphics.getSystemFont()
    local w = font:getTextWidth(label)
    Graphics.drawText(label, (400 - w) // 2, 8)
end

function scene:exit()
    scene.super.exit(self)
    if newb then
        newb:remove()
        newb = nil
    end
end

scene.inputHandler = {}
