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

-- Called once per frame from the scene update.  Reads the d-pad, picks a
-- facing, switches state, and applies movement.
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
    else
        self:changeState('idle_' .. self.facing)
    end
end
