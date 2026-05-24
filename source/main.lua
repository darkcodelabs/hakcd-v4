-- HAKCD v4 — Foundation rewrite
-- Stack: Noble Engine + LDtk + AnimatedSprite + GFXP

import 'libraries/noble/Noble'
import 'libraries/ldtk/LDtk'
import 'libraries/animatedsprite/AnimatedSprite'
import 'libraries/gfxp/gfxp'

import 'utilities/Utilities'

import 'sprites/Newb'
import 'scenes/TitleScene'
import 'scenes/SpriteTestScene'

Noble.showFPS = false

-- TEMP (Agent 2 / SPRITE): boot straight into SpriteTestScene so a sideload
-- verifies the newb 32x32 imagetable + d-pad-driven AnimatedSprite FSM.
-- Agent 4 (PORT) will restore `Noble.new(TitleScene)` when wiring scene flow.
Noble.new(SpriteTestScene)
