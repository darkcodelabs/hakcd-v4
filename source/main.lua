-- HAKCD v4 — Foundation rewrite
-- Stack: Noble Engine + LDtk + AnimatedSprite + GFXP

import 'libraries/noble/Noble'
import 'libraries/ldtk/LDtk'
import 'libraries/animatedsprite/AnimatedSprite'
import 'libraries/gfxp/gfxp'

import 'utilities/Utilities'

import 'scenes/TitleScene'

Noble.showFPS = false

Noble.new(TitleScene)
