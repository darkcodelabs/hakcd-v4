-- HAKCD v4 — sound manifest
--
-- Wires the 14 bespoke SFX (synthesized by tools/audio/synth_v4_sfx.js)
-- and the 5 keygen music tracks (encoded by Agent 5 from Bootstrap's
-- normalized 25-track pool) into a single global API.
--
-- Usage from any scene:
--   sound_manifest.play_sfx('lockpick_open')
--   local fp = sound_manifest.music_for('TitleScene')
--   if fp then fp:play(0) end   -- 0 = loop forever
--
-- Variant lists (e.g. lockpick_pin_click) are resolved randomly per call.

local M = {}

-- Scene -> music sample path (relative to /Source/ root, no .wav extension).
M.music_for_scene = {
    TitleScene      = 'sounds/music/title_loop',
    BedroomScene    = 'sounds/music/bedroom_loop',
    PlaygroundScene = 'sounds/music/playground_loop',
    LockpickScene   = nil,   -- silent during minigame
    TysonScene      = 'sounds/music/tyson_loop',
    CoinVaultScene  = 'sounds/music/coinvault_loop',
}

-- SFX name -> sample path (or list of paths for variants).
M.sfx_paths = {
    lockpick_pin_click    = {
        'sounds/sfx/lockpick_pin_click_1',
        'sounds/sfx/lockpick_pin_click_2',
        'sounds/sfx/lockpick_pin_click_3',
        'sounds/sfx/lockpick_pin_click_4',
    },
    lockpick_pin_set      = 'sounds/sfx/lockpick_pin_set',
    lockpick_snap         = 'sounds/sfx/lockpick_snap',
    lockpick_tension_warn = 'sounds/sfx/lockpick_tension_warn',
    lockpick_open         = 'sounds/sfx/lockpick_open',
    tyson_digit_select    = 'sounds/sfx/tyson_digit_select',
    tyson_digit_commit    = 'sounds/sfx/tyson_digit_commit',
    tyson_winner          = 'sounds/sfx/tyson_winner',
    coin_navigate_tick    = 'sounds/sfx/coin_navigate_tick',
    coin_zoom_whoosh      = 'sounds/sfx/coin_zoom_whoosh',
    coin_mint             = 'sounds/sfx/coin_mint',
    pwnglove_boot         = 'sounds/sfx/pwnglove_boot',
}

-- Play a one-shot SFX by manifest name. No-ops if the name is unknown so
-- callers don't need to guard every call.
function M.play_sfx(name)
    local target = M.sfx_paths[name]
    if not target then return end
    if type(target) == 'table' then
        target = target[math.random(#target)]
    end
    local p = playdate.sound.sampleplayer.new(target)
    if p then p:play(1) end
end

-- Build (don't auto-play) a looping fileplayer for the given scene.
-- Returns nil if the scene has no music wired or if the file is missing.
-- Caller is responsible for :play(0) and :stop() on scene exit.
function M.music_for(scene_name)
    local path = M.music_for_scene[scene_name]
    if not path then return nil end
    local fp = playdate.sound.fileplayer.new(path)
    if fp then fp:setLoopRange(0) end
    return fp
end

_G.sound_manifest = M
return M
