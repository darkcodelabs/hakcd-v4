-- Newb — d-pad-driven player sprite for HAKCD.
--
-- Wraps AnimatedSprite with a 10-state FSM that maps onto the 26-frame
-- newb imagetable (4x7 grid at source/images/newb-table-32-32.png).
--
-- States:
--   idle_<dir>  — 1-2 frame breathing or single hold
--   walk_<dir>  — 4-frame walk cycle, tickStep 6
--   interact   — single frame, arm extended forward (south view)
--   surprised  — single frame, arms raised, exclamation above hood
--
-- Direction priority on diagonals: horizontal beats vertical.

import 'libraries/animatedsprite/AnimatedSprite'

class('Newb').extends(AnimatedSprite)

local SPEED <const> = 2

function Newb:init(x, y)
    local imagetable = playdate.graphics.imagetable.new('images/newb-table-32-32')
    assert(imagetable, 'Newb: failed to load images/newb-table-32-32')
    Newb.super.init(self, imagetable)

    -- Frame ranges match the documented 4x7 imagetable layout.
    self:addState('idle_south',  1,  2,  { tickStep = 30 })
    self:addState('walk_south',  3,  6,  { tickStep = 6 })
    self:addState('idle_north',  7,  7)
    self:addState('walk_north',  8, 11,  { tickStep = 6 })
    self:addState('idle_east',  13, 13)
    self:addState('walk_east',  14, 17,  { tickStep = 6 })
    self:addState('idle_west',  19, 19)
    self:addState('walk_west',  20, 23,  { tickStep = 6 })
    self:addState('interact',   25, 25)
    self:addState('surprised',  26, 26)

    self:playAnimation()
    self:changeState('idle_south')
    self:moveTo(x, y)
    self:setCollideRect(4, 8, 24, 24)
    self:add()

    self.facing = 'south'
end

-- Footstep cadence: at SPEED=2 and ~30Hz Playdate update, one step ≈
-- every 14 frames feels natural. Track frames-since-last-step so we
-- don't spam SFX every update.
local STEP_FRAMES <const> = 14

-- Called once per frame from the scene update.  Reads the d-pad, picks a
-- facing, switches state, and applies movement. Emits 'step' SFX at
-- STEP_FRAMES cadence while walking.
function Newb:updateMovement()
    local pd = playdate
    local dx, dy = 0, 0
    if pd.buttonIsPressed(pd.kButtonLeft)  then dx = -SPEED end
    if pd.buttonIsPressed(pd.kButtonRight) then dx =  SPEED end
    if pd.buttonIsPressed(pd.kButtonUp)    then dy = -SPEED end
    if pd.buttonIsPressed(pd.kButtonDown)  then dy =  SPEED end

    if dx ~= 0 or dy ~= 0 then
        -- Horizontal beats vertical when both pressed (matches sprite docs).
        if dx > 0 then
            self.facing = 'east'
        elseif dx < 0 then
            self.facing = 'west'
        elseif dy > 0 then
            self.facing = 'south'
        elseif dy < 0 then
            self.facing = 'north'
        end
        self:changeState('walk_' .. self.facing)
        self:moveBy(dx, dy)

        -- footstep emission
        self._stepFrames = (self._stepFrames or STEP_FRAMES) + 1
        if self._stepFrames >= STEP_FRAMES then
            self._stepFrames = 0
            if _G.sound_manifest and _G.sound_manifest.play_sfx then
                _G.sound_manifest.play_sfx('step')
            end
        end
    else
        self:changeState('idle_' .. self.facing)
        self._stepFrames = STEP_FRAMES   -- reset so first step on resume fires immediately
    end
end
