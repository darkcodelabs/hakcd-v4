-- TitleScene — boot scene. Canonical hakcd_title.png full-frame + blinking
-- "press any key" prompt. A or B advances to BedroomScene.

TitleScene = {}
class("TitleScene").extends(NobleScene)
local scene = TitleScene
local gfx <const> = playdate.graphics

scene.backgroundColor = Graphics.kColorBlack

local BLINK_MS = 700
local PROMPT = "press any key"

function scene:init(__sceneProperties)
    scene.super.init(self)
    self._title_img = gfx.image.new("images/title")
end

function scene:enter()
    scene.super.enter(self)
    self._enter_ms = playdate.getCurrentTimeMilliseconds()
    if _G.sound_manifest and _G.sound_manifest.start_scene_music then
        _G.sound_manifest.start_scene_music('TitleScene')
    end
end

function scene:drawBackground()
    scene.super.drawBackground(self)

    if self._title_img then
        self._title_img:draw(0, 0)
    else
        gfx.setColor(gfx.kColorWhite)
        gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        gfx.drawTextAligned("HAKCD", 200, 110, kTextAlignment.center)
    end

    -- Blink the prompt every BLINK_MS.
    local elapsed = playdate.getCurrentTimeMilliseconds() - (self._enter_ms or 0)
    if (elapsed // BLINK_MS) % 2 == 0 then
        gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        gfx.drawTextAligned(PROMPT, 200, 220, kTextAlignment.center)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
end

local function advance()
    if BedroomScene then
        Noble.transition(BedroomScene)
    end
end

scene.inputHandler = {
    AButtonDown = advance,
    BButtonDown = advance
}
