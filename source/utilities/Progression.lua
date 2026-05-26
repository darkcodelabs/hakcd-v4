-- utilities/Progression.lua
-- Typed wrapper over Noble.GameData. Scenes call this for game state;
-- never write Noble.GameData directly. Audio prefs still legacy through
-- Noble.GameData.musicVolume etc.
--
-- Save root key: 'state'  (single Noble.GameData entry, deep-nested table)
--
-- Shape:
--   state = {
--     coins = { ["0"]={status='minted'}, ["1"]={status='available'}, ... },
--     inventory = { 'red_box', 'blue_box', ... },
--     current_act = 1,
--     completed_scenes = { sc01_bedroom = true, ... },
--     tyson_unlock = false,
--     pwnglove_mode_complete = false,
--   }
--
-- API:
--   Progression.init()                          ensure state scaffold
--   Progression.coin_status(id)                 'minted'|'available'|'locked'
--   Progression.set_coin_status(id, status)     persist
--   Progression.mint_coin(id)                   shortcut
--   Progression.unlock_coin(id)                 locked -> available
--   Progression.minted_count() -> int
--
--   Progression.has_item(id)
--   Progression.add_item(id)
--
--   Progression.act() -> 1..4
--   Progression.advance_act()
--
--   Progression.is_scene_complete(scene_id)
--   Progression.complete_scene(scene_id)
--
--   Progression.tyson_unlocked() -> bool
--   Progression.set_tyson_unlocked(bool)
--
--   Progression.pwnglove_mode_complete() -> bool
--   Progression.set_pwnglove_mode_complete(bool)
--
--   Progression.get_flag(flag_id)               typed read, soft-fails unknown ids
--   Progression.set_flag(flag_id, value)        typed write, HARD-asserts canon
--   Progression.assert_flag_id(flag_id)         helper: read-side soft check
--
--   Progression.dump() -> table   (debug)
--
-- Phase 8 (v0.1.19) — runtime canon guards:
--   WRITES go through Progression.set_flag, which asserts the flag id is in
--   canon.state_flags. Typo or undeclared flag -> immediate crash on sideload.
--   READS go through Progression.get_flag, which soft-warns on unknown ids
--   (a previously-saved game whose flag was retired must not brick on boot).

Progression = {}

local DEFAULT_STATE = {
    coins = {},
    inventory = {},
    current_act = 1,
    completed_scenes = {},
    tyson_unlock = false,
    pwnglove_mode_complete = false,
}

local function deep_copy(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = deep_copy(v) end
    return out
end

-- Default coin state seeded from source/data/coins.json status_default.
-- Loaded lazily so this module doesn't depend on file read at require time.
local _coin_defaults = nil
local function _load_coin_defaults()
    if _coin_defaults then return _coin_defaults end
    _coin_defaults = {}
    local f = playdate.file.open('data/coins.json', playdate.file.kFileRead)
    if not f then return _coin_defaults end
    local raw = ''
    while true do
        local chunk = f:read(4096)
        if not chunk or chunk == '' then break end
        raw = raw .. chunk
    end
    f:close()
    local parsed = json and json.decode(raw)
    if parsed and parsed.coins then
        for _, c in ipairs(parsed.coins) do
            _coin_defaults[tostring(c.id)] = { status = c.status_default or 'locked' }
        end
    end
    return _coin_defaults
end

local function _get_state()
    local s = nil
    if Noble and Noble.GameData and Noble.GameData.get then
        local ok, v = pcall(Noble.GameData.get, 'state')
        if ok and type(v) == 'table' then s = v end
    end
    if not s then s = deep_copy(DEFAULT_STATE) end
    -- Ensure subtables exist (Noble.GameData may strip nils across versions)
    s.coins = s.coins or {}
    s.inventory = s.inventory or {}
    s.completed_scenes = s.completed_scenes or {}
    s.current_act = s.current_act or 1
    if s.tyson_unlock == nil then s.tyson_unlock = false end
    if s.pwnglove_mode_complete == nil then s.pwnglove_mode_complete = false end
    return s
end

local function _save_state(s)
    if Noble and Noble.GameData and Noble.GameData.set then
        pcall(Noble.GameData.set, 'state', s, true)   -- 3rd arg = save immediately
    end
end

----------------------------------------------------------------------
-- Canon-guarded typed flag wrappers (Phase 8)
----------------------------------------------------------------------

-- Read-side helper: returns the canon def for a flag, or nil + logs on
-- miss. We deliberately do NOT crash on read because a save file may
-- carry a flag that was retired in a later canon revision; the game must
-- still boot. Print so the dev sees it on sideload.
function Progression.assert_flag_id(flag_id)
    if not (canon and canon.state_flags) then return nil end
    local def = canon.state_flags[flag_id]
    if not def then
        print("[Progression] WARN: unknown state_flag id '" .. tostring(flag_id) ..
              "' (not in canon.state_flags) — returning nil")
        return nil
    end
    return def
end

-- Write-side helper: HARD assert. A scene writing an undeclared flag is a
-- canon-drift bug — surface it loudly, don't let it pollute save state.
local function _assert_flag_for_write(flag_id)
    if canon and canon.assert_id then
        canon.assert_id('state_flags', flag_id)
    else
        error("[Progression] canon module missing — cannot guard flag write '" ..
              tostring(flag_id) .. "'")
    end
end

-- get_flag: route every typed read through the canon soft-check, then
-- dereference the save shape. Coin flags (coin_<N>_status) and the
-- legacy named flags (tyson_unlock, pwnglove_mode_complete, current_act)
-- all live in different sub-tables of `state` — this wrapper hides that.
function Progression.get_flag(flag_id)
    Progression.assert_flag_id(flag_id)   -- soft-warns on unknown id
    local s = _get_state()
    -- Coin status flags: coin_<N>_status -> s.coins[tostring(N)].status
    local coin_n = string.match(flag_id, '^coin_(%d+)_status$')
    if coin_n then
        local c = s.coins[coin_n]
        if c and c.status then return c.status end
        local defaults = _load_coin_defaults()
        local d = defaults[coin_n]
        return (d and d.status) or 'locked'
    end
    -- Named scalar flags live at the top of `state`.
    return s[flag_id]
end

-- set_flag: HARD-asserts canon membership, then writes through the
-- appropriate sub-table.
function Progression.set_flag(flag_id, value)
    _assert_flag_for_write(flag_id)
    local s = _get_state()
    local coin_n = string.match(flag_id, '^coin_(%d+)_status$')
    if coin_n then
        s.coins[coin_n] = s.coins[coin_n] or {}
        s.coins[coin_n].status = value
    else
        s[flag_id] = value
    end
    _save_state(s)
end

----------------------------------------------------------------------

function Progression.init()
    local s = _get_state()
    -- Seed missing coin entries from coins.json defaults
    local defaults = _load_coin_defaults()
    for id_str, def in pairs(defaults) do
        if not s.coins[id_str] then s.coins[id_str] = deep_copy(def) end
    end
    _save_state(s)
end

----------------------------------------------------------------------
-- Coins  (now thin wrappers over get_flag/set_flag — canon-guarded)
----------------------------------------------------------------------

function Progression.coin_status(id)
    return Progression.get_flag('coin_' .. tostring(id) .. '_status')
end

function Progression.set_coin_status(id, status)
    Progression.set_flag('coin_' .. tostring(id) .. '_status', status)
end

function Progression.mint_coin(id)
    Progression.set_coin_status(id, 'minted')
end

function Progression.unlock_coin(id)
    local current = Progression.coin_status(id)
    if current == 'locked' then
        Progression.set_coin_status(id, 'available')
    end
end

function Progression.minted_count()
    local n = 0
    for i = 0, 23 do
        if Progression.coin_status(i) == 'minted' then n = n + 1 end
    end
    return n
end

----------------------------------------------------------------------
-- Inventory
----------------------------------------------------------------------

function Progression.has_item(id)
    local s = _get_state()
    for _, x in ipairs(s.inventory) do if x == id then return true end end
    return false
end

function Progression.add_item(id)
    if Progression.has_item(id) then return end
    local s = _get_state()
    table.insert(s.inventory, id)
    _save_state(s)
end

----------------------------------------------------------------------
-- Acts + scene-completion
----------------------------------------------------------------------

function Progression.act()
    return _get_state().current_act or 1
end

function Progression.advance_act()
    local s = _get_state()
    s.current_act = math.min(4, (s.current_act or 1) + 1)
    _save_state(s)
end

function Progression.is_scene_complete(scene_id)
    local s = _get_state()
    return s.completed_scenes[scene_id] == true
end

function Progression.complete_scene(scene_id)
    local s = _get_state()
    s.completed_scenes[scene_id] = true
    _save_state(s)
end

----------------------------------------------------------------------
-- Tyson master unlock + playground completion
-- (now canon-guarded via get_flag/set_flag — preserves boolean coercion)
----------------------------------------------------------------------

function Progression.tyson_unlocked()
    return Progression.get_flag('tyson_unlock') == true
end

function Progression.set_tyson_unlocked(bool)
    Progression.set_flag('tyson_unlock', bool and true or false)
end

function Progression.pwnglove_mode_complete()
    return Progression.get_flag('pwnglove_mode_complete') == true
end

function Progression.set_pwnglove_mode_complete(bool)
    Progression.set_flag('pwnglove_mode_complete', bool and true or false)
end

----------------------------------------------------------------------
-- Debug
----------------------------------------------------------------------

function Progression.dump()
    return deep_copy(_get_state())
end

_G.Progression = Progression
return Progression
