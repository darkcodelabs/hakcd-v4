-- HAKCD v4 — Foundation rewrite
-- Stack: Noble Engine + LDtk + AnimatedSprite + GFXP

import 'libraries/noble/Noble'
import 'libraries/ldtk/LDtk'
import 'libraries/animatedsprite/AnimatedSprite'
import 'libraries/gfxp/gfxp'

import 'utilities/Utilities'
import 'data/canon'
import 'data/continuity'
import 'data/assets'
import 'data/animations'
import 'data/rooms'
import 'utilities/Progression'

-- Agent 5 (CONTENT): wires sound_manifest global. Scenes call
-- sound_manifest.play_sfx(name) / sound_manifest.music_for(scene_name).
import 'sounds/manifest'

-- Phase 11: SceneRouter must be live before any scene file is loaded so the
-- _G.SceneRouter reference resolves at scene-class definition time. Scenes
-- only *call* it inside update/inputHandler closures, but importing first
-- keeps the dependency direction one-way + obvious.
import 'systems/SceneRouter'

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

-- Seed progression scaffold (idempotent — pulls coin defaults from
-- coins.json on first run, leaves existing state alone after).
if Progression and Progression.init then Progression.init() end

-- Boot-time canon sanity sweep — fail loudly on any undeclared id reference.
-- Catches drift between generated manifests and runtime expectations. The
-- Phase 7 validator catches the same drift at build-time; this is the
-- runtime backstop for sideloaded dev builds that bypassed `make`.
local function _boot_canon_sanity()
    assert(canon, 'canon module missing')
    assert(canon.scenes, 'canon.scenes missing')
    assert(canon.state_flags, 'canon.state_flags missing')
    assert(canon.objects, 'canon.objects missing')
    -- Verify every state_flag entry's id field matches its key
    for fid, fdef in pairs(canon.state_flags) do
        assert(fdef.id == fid, 'canon.state_flags['..fid..'].id mismatch')
    end
    -- Verify every object.launches resolves to a scene
    for oid, obj in pairs(canon.objects) do
        if obj.launches then
            assert(canon.scenes[obj.launches],
                'canon.objects['..oid..'].launches='..tostring(obj.launches)..' not in canon.scenes')
        end
    end
end
_boot_canon_sanity()

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
    -- Prefer the checkpointed scene by id when canon knows about it; fall
    -- back to TitleScene class direct so this path still works for any
    -- developer-only scene name that never made it into canon.scenes.
    if target_name and canon and canon.scenes and canon.scenes[target_name] then
        SceneRouter.transition_by_id(target_name)
    else
        SceneRouter.transition(TitleScene)
    end
end

local menu = playdate.getSystemMenu()
if menu then
    menu:addMenuItem('pwnglove mode', function()
        push_checkpoint()
        SceneRouter.transition_by_id('PlaygroundScene')
    end)
    menu:addMenuItem('back to story', function()
        restore_checkpoint()
    end)
end
