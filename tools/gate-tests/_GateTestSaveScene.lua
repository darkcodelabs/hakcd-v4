-- Gate Test 1 — Noble.GameData vs 24-coin schema
--
-- Verifies Noble.GameData (which wraps playdate.datastore) can roundtrip the
-- nested 24-coin table identical in shape to
-- /home/hakcer/projects/personal/hakcd/source/data/coins.json.
--
-- pdc-compile-time validation only. Not imported by main.lua.
-- To run on hardware: add `import 'scenes/_GateTestSaveScene'` to main.lua,
-- then `Noble.new(_GateTestSaveScene)`. The scene prints OK or FAIL on enter.

_GateTestSaveScene = {}
class("_GateTestSaveScene").extends(NobleScene)
local scene = _GateTestSaveScene

scene.backgroundColor = Graphics.kColorWhite

-- Build a 24-coin table matching coins.json shape:
--   { id=int, title=str, status_default=str, art_grid=str, art_closeup=str,
--     dialog = { grid_highlight=str, closeup=str, linger=str, [long_linger=str] } }
local function buildCoins()
    local coins = {}
    -- Known 4 from coins.json
    table.insert(coins, {
        id = 0, title = "WELCOME COIN", status_default = "minted",
        art_grid = "images/coins/coin_0", art_closeup = "images/coins/coin_0_large",
        dialog = {
            grid_highlight = "Coin Zero. Minted on first visit. Phrase locked.",
            closeup = "Twenty-three. The number SecKC chose.",
            linger = "Lloyd Blankenship would've appreciated this."
        }
    })
    table.insert(coins, {
        id = 1, title = "ROTARY DIAL", status_default = "available",
        art_grid = "images/coins/coin_1", art_closeup = "images/coins/coin_1_large",
        dialog = {
            grid_highlight = "Coin One. Phone dial. Phreaker shit.",
            closeup = "The face in the middle. Some kind of grinning Bond villain.",
            linger = "AABBB ABBAB AAABB. That's letters. Need to decode it."
        }
    })
    table.insert(coins, {
        id = 2, title = "LOST WAGES", status_default = "available",
        art_grid = "images/coins/coin_2", art_closeup = "images/coins/coin_2_large",
        dialog = {
            grid_highlight = "Coin Two. This one's a fucking maze.",
            closeup = "PBEL. That's PBEL backwards.",
            linger = "Suddenly you are standing in the cavern of PBEL.",
            long_linger = "I lived here too long. Speak & Spell knows."
        }
    })
    table.insert(coins, {
        id = 3, title = "YODA HASH", status_default = "locked",
        art_grid = "images/coins/coin_3", art_closeup = "images/coins/coin_3_large",
        dialog = {
            grid_highlight = "Coin Three. Yoda. With a hash tattoo. Sure.",
            closeup = "1QZ9M9G3E6WXK7. That's 14 chars.",
            linger = "Marching ants on the cheek."
        }
    })
    -- Placeholder shape for coins 4..23 — Phase-N content fills these in
    for i = 4, 23 do
        table.insert(coins, {
            id = i,
            title = "COIN " .. i,
            status_default = "locked",
            art_grid = "images/coins/coin_" .. i,
            art_closeup = "images/coins/coin_" .. i .. "_large",
            dialog = {
                grid_highlight = "Coin " .. i .. " grid highlight placeholder.",
                closeup = "Coin " .. i .. " closeup placeholder.",
                linger = "Coin " .. i .. " linger placeholder."
            }
        })
    end
    return coins
end

-- Deep equality for the coin table (string/number/table only — no userdata).
local function deepEqual(a, b)
    if type(a) ~= type(b) then return false, "type mismatch: " .. type(a) .. " vs " .. type(b) end
    if type(a) ~= "table" then
        if a ~= b then return false, "value mismatch: " .. tostring(a) .. " vs " .. tostring(b) end
        return true
    end
    for k, v in pairs(a) do
        local ok, err = deepEqual(v, b[k])
        if not ok then return false, "at key '" .. tostring(k) .. "': " .. err end
    end
    for k, _ in pairs(b) do
        if a[k] == nil then return false, "extra key '" .. tostring(k) .. "' on roundtrip" end
    end
    return true
end

function scene:init()
    scene.super.init(self)
end

function scene:enter()
    scene.super.enter(self)

    print("[GATE-TEST-1] Building 24-coin table...")
    local coins = buildCoins()
    assert(#coins == 24, "expected 24 coins, got " .. #coins)

    -- Noble.GameData.setup() is single-shot. If the host main.lua already
    -- called setup(), this block is a no-op verification; otherwise it sets
    -- up a 'coins' key holding the entire 24-entry nested array.
    local ok, err = pcall(function()
        Noble.GameData.setup({ coins = {} }, 1, true, true)
    end)
    if not ok then
        print("[GATE-TEST-1] Noble.GameData.setup already called (expected on second run): " .. tostring(err))
    end

    print("[GATE-TEST-1] Writing 24-coin payload via Noble.GameData...")
    Noble.GameData.set("coins", coins, 1, true, true)

    print("[GATE-TEST-1] Reading back...")
    local readBack = Noble.GameData.get("coins", 1)

    local eq, mismatch = deepEqual(coins, readBack)
    if eq then
        print("[GATE-TEST-1] OK — 24-coin nested schema roundtrips through Noble.GameData (playdate.datastore)")
    else
        print("[GATE-TEST-1] FAIL — " .. tostring(mismatch))
    end
end

function scene:drawBackground()
    scene.super.drawBackground(self)
    Graphics.setColor(Graphics.kColorBlack)
    Graphics.drawText("Gate Test 1 — see console", 60, 110)
end
