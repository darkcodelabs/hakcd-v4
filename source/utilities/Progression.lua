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
--   Progression.dump() -> table   (debug)

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
-- Coins
----------------------------------------------------------------------

function Progression.coin_status(id)
    local s = _get_state()
    local c = s.coins[tostring(id)]
    if c and c.status then return c.status end
    local defaults = _load_coin_defaults()
    local d = defaults[tostring(id)]
    return (d and d.status) or 'locked'
end

function Progression.set_coin_status(id, status)
    local s = _get_state()
    s.coins[tostring(id)] = s.coins[tostring(id)] or {}
    s.coins[tostring(id)].status = status
    _save_state(s)
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
----------------------------------------------------------------------

function Progression.tyson_unlocked()
    return _get_state().tyson_unlock == true
end

function Progression.set_tyson_unlocked(bool)
    local s = _get_state()
    s.tyson_unlock = bool and true or false
    _save_state(s)
end

function Progression.pwnglove_mode_complete()
    return _get_state().pwnglove_mode_complete == true
end

function Progression.set_pwnglove_mode_complete(bool)
    local s = _get_state()
    s.pwnglove_mode_complete = bool and true or false
    _save_state(s)
end

----------------------------------------------------------------------
-- Debug
----------------------------------------------------------------------

function Progression.dump()
    return deep_copy(_get_state())
end

_G.Progression = Progression
return Progression
