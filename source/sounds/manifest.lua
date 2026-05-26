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
    -- Bedroom modal scenes share bedroom_loop so transitions in/out don't
    -- restart the track (start_scene_music compares by path, not name).
    ComputerScene   = 'sounds/music/bedroom_loop',
    ModemScene      = 'sounds/music/bedroom_loop',
    PhoneScene      = 'sounds/music/bedroom_loop',
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
    step                  = {
        'sounds/sfx/step_1',
        'sounds/sfx/step_2',
    },
}

-- Scene-bound music player. Single global fileplayer.
-- Comparison is by PATH not scene name, so multiple scene names that
-- alias to the same track (e.g. Bedroom + Computer + Modem + Phone all
-- → bedroom_loop) keep playing through transitions without stop+restart.
-- Pass nil scene_name or unknown scene to silence.
M._currentMusic = nil       -- live fileplayer
M._currentPath  = nil       -- path currently playing (or nil)

function M.start_scene_music(scene_name)
    local path = M.music_for_scene[scene_name]
    if path == nil then
        M.stop_scene_music()
        return
    end
    if path == M._currentPath and M._currentMusic and M._currentMusic:isPlaying() then
        return   -- same track already playing, no-op
    end
    M.stop_scene_music()
    local fp = playdate.sound.fileplayer.new(path)
    if not fp then return end
    fp:setVolume(0.7)
    fp:play(0)   -- 0 = loop forever
    M._currentMusic = fp
    M._currentPath  = path
end

function M.stop_scene_music()
    if M._currentMusic then
        M._currentMusic:stop()
        M._currentMusic = nil
    end
    M._currentPath = nil
end

-- Phase 14 perf fix #4: pre-cache one sampleplayer per SFX path at boot.
-- Hardware audit FAIL — previously every play_sfx() call did
-- `playdate.sound.sampleplayer.new(path)`, which re-opens the audio file
-- on every shot. Now we build one cached sampleplayer per path at boot
-- and reuse it via :play(1). Variant lists become arrays of cached
-- sampleplayers indexed the same way the variant id was indexed before.
M._sfx_cache = {}

local function _new_sampler(path)
    if not path then return nil end
    return playdate.sound.sampleplayer.new(path)
end

function M.preload_sfx()
    for name, target in pairs(M.sfx_paths) do
        if type(target) == 'table' then
            local variants = {}
            for i, v in ipairs(target) do
                variants[i] = _new_sampler(v)
            end
            M._sfx_cache[name] = variants
        else
            M._sfx_cache[name] = _new_sampler(target)
        end
    end
end

-- Play a one-shot SFX by manifest name. No-ops if the name is unknown so
-- callers don't need to guard every call. Uses the pre-cached sampleplayer
-- built by preload_sfx() at boot; if the cache is cold (e.g. unit-test
-- import path) we fall back to constructing one on demand.
function M.play_sfx(name)
    local cached = M._sfx_cache[name]
    if cached ~= nil then
        local p = cached
        if type(p) == 'table' then
            p = p[math.random(#p)]
        end
        if p then p:play(1) end
        return
    end
    -- Cold-cache fallback (preload_sfx not called yet).
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
