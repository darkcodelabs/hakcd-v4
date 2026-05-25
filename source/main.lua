-- HAKCD v4 — Foundation rewrite
-- Stack: Noble Engine + LDtk + AnimatedSprite + GFXP

import 'libraries/noble/Noble'
import 'libraries/ldtk/LDtk'
import 'libraries/animatedsprite/AnimatedSprite'
import 'libraries/gfxp/gfxp'

import 'utilities/Utilities'

-- Agent 5 (CONTENT): wires sound_manifest global. Scenes call
-- sound_manifest.play_sfx(name) / sound_manifest.music_for(scene_name).
import 'sounds/manifest'

import 'sprites/Newb'
import 'scenes/TitleScene'
import 'scenes/SpriteTestScene'   -- importable for ad-hoc sprite testing
import 'scenes/BedroomScene'
import 'scenes/PlaygroundScene'
import 'scenes/LockpickScene'
import 'scenes/TysonScene'
import 'scenes/CoinVaultScene'
import 'scenes/ComputerScene'
import 'scenes/ModemScene'
import 'scenes/PhoneScene'

Noble.showFPS = false

-- Boot scene is the canonical title (Agent 4 / PORT). SpriteTestScene is
-- still importable so devs can wire it in manually for ad-hoc testing.
Noble.new(TitleScene)

-- System menu items (registered after Noble.new so getSystemMenu is live).
-- "pwnglove mode"  jumps straight to the playground sandbox (cheats in for
--                  demos and dev runs). Pushes a checkpoint of the previous
--                  scene name to a tiny module-local stack so "back to
--                  story" can return.
-- "back to story"  pops that checkpoint and returns to TitleScene
--                  (or whatever was checkpointed).
local _scene_checkpoint = nil

local function push_checkpoint()
    local cur = Noble.currentScene()
    if cur and cur.className then
        _scene_checkpoint = cur.className
    end
end

local function restore_checkpoint()
    local target_name = _scene_checkpoint
    _scene_checkpoint = nil
    local target = (target_name and _G[target_name]) or TitleScene
    Noble.transition(target)
end

local menu = playdate.getSystemMenu()
if menu then
    menu:addMenuItem('pwnglove mode', function()
        push_checkpoint()
        Noble.transition(PlaygroundScene)
    end)
    menu:addMenuItem('back to story', function()
        restore_checkpoint()
    end)
end
