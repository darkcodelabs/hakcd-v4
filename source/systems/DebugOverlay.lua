-- DebugOverlay — Phase 14 perf HUD.
--
-- Toggle via the 'debug overlay' system menu item registered in main.lua.
-- When enabled, draws a 100x60 panel in the top-right of every frame
-- (after Noble's transition canvas) showing:
--   FPS  — playdate.getFPS()
--   SCN  — Noble.currentScene().className (truncated to 8 chars)
--   SPR  — total sprite count
--   NWB  — current Newb FSM state (if Newb is on the scene graph)
--   MEM  — Lua heap size in KB (collectgarbage('count'))
--
-- All five lines refresh every frame. Memory + sprite count are cheap
-- enough that the audit's "refresh once per 30 frames" guidance is
-- over-engineered for the current scene set; revisit if the HUD itself
-- shows up in profiling.
--
-- Position: x=296 y=4 size 100x60 — clears the top-right sleep clock area.
-- Drawn after Noble's transitionCanvas so it floats on top regardless
-- of scene draw order.

DebugOverlay = { enabled = false }

function DebugOverlay.toggle()
    DebugOverlay.enabled = not DebugOverlay.enabled
end

function DebugOverlay.isOn()
    return DebugOverlay.enabled
end

function DebugOverlay.draw()
    if not DebugOverlay.enabled then return end
    local gfx = playdate.graphics
    local X, Y, W, H = 296, 4, 100, 60

    -- Save current draw mode so we don't poison the next scene's draws.
    local prevMode = gfx.getImageDrawMode()
    local prevColor = gfx.getColor()

    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(X, Y, W, H)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(X, Y, W, H)

    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)

    local fps = playdate.getFPS()
    local scene = Noble and Noble.currentScene and Noble.currentScene()
    local sceneName = (scene and scene.className) or '?'
    if #sceneName > 8 then sceneName = sceneName:sub(1, 8) end

    local sprite_count = '?'
    if gfx.sprite and gfx.sprite.spriteCount then
        sprite_count = tostring(gfx.sprite.spriteCount())
    elseif gfx.sprite and gfx.sprite.getAllSprites then
        sprite_count = tostring(#gfx.sprite.getAllSprites())
    end

    local newb_state = '?'
    if scene and scene.newb and scene.newb.currentState then
        local s = scene.newb.currentState
        if type(s) == 'table' and s.name then newb_state = s.name
        elseif type(s) == 'string' then newb_state = s end
    end

    local heap_kb = math.floor(collectgarbage('count'))

    gfx.drawText('FPS ' .. tostring(fps),    X + 4, Y + 2)
    gfx.drawText('SCN ' .. sceneName,        X + 4, Y + 14)
    gfx.drawText('SPR ' .. sprite_count,     X + 4, Y + 26)
    gfx.drawText('NWB ' .. tostring(newb_state), X + 4, Y + 38)
    gfx.drawText('MEM ' .. tostring(heap_kb) .. 'K', X + 4, Y + 50)

    gfx.setImageDrawMode(prevMode)
    gfx.setColor(prevColor)
end

_G.DebugOverlay = DebugOverlay
return DebugOverlay
