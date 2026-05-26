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

    -- Phase 9 canon-first migration: load states from the generated
    -- animations.lua manifest (source/data/animations.lua) instead of
    -- inline addState literals. The manifest is the single source-of-truth
    -- linked back to the story bible via bible_anim_id and validated by
    -- the Phase 7 continuity validator against asset.frame_count.
    local specs = _G.animations_manifest and _G.animations_manifest.newb
    assert(specs, 'Newb: animations_manifest.newb missing — data/animations not loaded before sprites')

    for state_name, spec in pairs(specs) do
        if spec.frames and #spec.frames > 0 then
            local frames = spec.frames
            local opts = {
                tickStep = spec.frameDuration or 6,
                loop     = (spec.loop ~= false),
            }
            -- AnimatedSprite addState signature: (name, startFrame, endFrame, params).
            -- For non-contiguous frames (e.g. {7, 12} breathing variants in
            -- blank-slot cells) the library reads params.frames as the
            -- explicit playback list.
            if #frames == 1 then
                self:addState(state_name, frames[1], frames[1], opts)
            elseif frames[#frames] - frames[1] == #frames - 1 then
                -- contiguous range — let the lib walk start..end
                self:addState(state_name, frames[1], frames[#frames], opts)
            else
                -- non-contiguous — pass explicit frame list via params.frames
                opts.frames = frames
                self:addState(state_name, frames[1], frames[#frames], opts)
            end
        end
    end

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
