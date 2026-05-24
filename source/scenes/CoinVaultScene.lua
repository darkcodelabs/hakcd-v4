-- CoinVaultScene — 23 C0iNS display-only modal viewer.
-- Port of v0.0.3 scenes/coin_vault_viewer.lua wrapped in NobleScene.
-- 4x6 grid, D-pad navigates, A zooms, B returns / exits.
-- Layout is pixel-tight against /home/hakcer/projects/23studios/docs/coingame.png
-- per the v4 32-tile grid measurements in the PORT spec.
--
-- v0.0.3 has 4 of 24 coins defined (0..3). Coins 4..23 render with
-- coin_locked.png + "???" sidebar title — that's expected for this sprint.
--
-- SFX (Agent 5 / CONTENT, may not exist yet):
--   coin_navigate_tick, coin_zoom_whoosh, coin_mint

CoinVaultScene = {}
class("CoinVaultScene").extends(NobleScene)
local scene = CoinVaultScene
local gfx <const> = playdate.graphics

scene.backgroundColor = Graphics.kColorWhite

-- ============================================================
-- LAYOUT
-- ============================================================
local SCREEN_W, SCREEN_H = 400, 240
local TOP_BAR_Y, TOP_BAR_H = 0, 12

local GRID_X, GRID_Y = 8, 14
local CELL_W, CELL_H = 60, 26
local CELL_GAP_X, CELL_GAP_Y = 2, 1
local COLS, ROWS = 4, 6
local TOTAL_COINS = COLS * ROWS  -- 24

local SIDE_X = 260
local SIDE_W = 138
local SIDE_INNER_X = SIDE_X + 4

local DIALOG_Y, DIALOG_H = 178, 62
local PORTRAIT_X = 348
local PORTRAIT_W = 48

-- ============================================================
-- HELPERS
-- ============================================================
local function sfx(name)
    if _G.sound_manifest and _G.sound_manifest.play_sfx then
        _G.sound_manifest.play_sfx(name)
    end
end

local function load_coins_json()
    local f = playdate.file.open("data/coins.json", playdate.file.kFileRead)
    if not f then return nil end
    local raw = ""
    while true do
        local chunk = f:read(4096)
        if not chunk or chunk == "" then break end
        raw = raw .. chunk
    end
    f:close()
    if json and json.decode then
        local ok, data = pcall(json.decode, raw)
        if ok then return data end
    end
    return nil
end

-- ============================================================
-- LIFECYCLE
-- ============================================================
function scene:init(__sceneProperties)
    scene.super.init(self)
    __sceneProperties = __sceneProperties or {}
    self._return_scene = __sceneProperties.return_scene
end

function scene:enter()
    scene.super.enter(self)

    local data = load_coins_json()
    self._coin_by_id = {}
    if data and data.coins then
        for _, c in ipairs(data.coins) do
            self._coin_by_id[c.id] = c
        end
    end

    self.cursor = 1            -- 1..24
    self.zoomed = false

    self.locked_img = gfx.image.new("images/coins/coin_locked")
    self.coin_imgs = {}
    self.coin_imgs_large = {}
    for i = 0, 3 do
        self.coin_imgs[i]       = gfx.image.new("images/coins/coin_" .. i)
        self.coin_imgs_large[i] = gfx.image.new("images/coins/coin_" .. i .. "_large")
    end
    self._newb_img = gfx.image.new("images/portraits/newb")

    self.dialog_lines = nil
    self.dialog_idx = 1
    self.dialog_advance_ms = 0
    self:_update_dialog_for_cursor()
end

function scene:exit()
    scene.super.exit(self)
    self.coin_imgs = nil
    self.coin_imgs_large = nil
end

function scene:_coin_at(cursor) return cursor - 1 end

function scene:_coin_status(id)
    -- v0.0.3 referenced progression.coin_status here. v4 doesn't have
    -- progression wired yet, so use the JSON's status_default field.
    local c = self._coin_by_id[id]
    if c and c.status_default then return c.status_default end
    if id == 0 then return 'minted' end
    if id <= 2 then return 'available' end
    return 'locked'
end

function scene:_minted_count()
    local n = 0
    for i = 0, TOTAL_COINS - 1 do
        if self:_coin_status(i) == 'minted' then n = n + 1 end
    end
    if n == 0 then n = 1 end  -- coin 0 starts minted regardless
    return n
end

function scene:_update_dialog_for_cursor()
    local id = self:_coin_at(self.cursor)
    local c = self._coin_by_id[id]
    local lines = {}
    if c and c.dialog then
        if self.zoomed then
            if c.dialog.closeup     then table.insert(lines, c.dialog.closeup) end
            if c.dialog.linger      then table.insert(lines, c.dialog.linger) end
            if c.dialog.long_linger then table.insert(lines, c.dialog.long_linger) end
        else
            if c.dialog.grid_highlight then
                table.insert(lines, c.dialog.grid_highlight)
            end
        end
    else
        table.insert(lines, "Locked. Phrase not yet discovered.")
    end
    self.dialog_lines = lines
    self.dialog_idx = 1
    self.dialog_advance_ms = playdate.getCurrentTimeMilliseconds() + 3000
end

-- ============================================================
-- UPDATE
-- ============================================================
function scene:update()
    scene.super.update(self)
    if not self.dialog_lines then return end
    if #self.dialog_lines > 1 and
       playdate.getCurrentTimeMilliseconds() > self.dialog_advance_ms then
        self.dialog_idx = (self.dialog_idx % #self.dialog_lines) + 1
        self.dialog_advance_ms = playdate.getCurrentTimeMilliseconds() + 3000
    end
end

-- ============================================================
-- INPUT
-- ============================================================
local function move(d_col, d_row)
    local s = Noble.currentScene()
    if not s or not s.cursor then return end
    local new = s.cursor
    if d_col ~= 0 then new = new + d_col end
    if d_row ~= 0 then new = new + d_row * COLS end
    if new >= 1 and new <= TOTAL_COINS then
        s.cursor = new
        s:_update_dialog_for_cursor()
        sfx('coin_navigate_tick')
    end
end

scene.inputHandler = {
    upButtonDown    = function() move(0, -1) end,
    downButtonDown  = function() move(0,  1) end,
    leftButtonDown  = function() move(-1, 0) end,
    rightButtonDown = function() move( 1, 0) end,
    AButtonDown = function()
        local s = Noble.currentScene()
        if not s then return end
        if not s.zoomed then
            s.zoomed = true
            s:_update_dialog_for_cursor()
            sfx('coin_zoom_whoosh')
        else
            -- A on closeup advances dialog if multi-line
            if s.dialog_lines and #s.dialog_lines > 1 then
                s.dialog_idx = (s.dialog_idx % #s.dialog_lines) + 1
                s.dialog_advance_ms = playdate.getCurrentTimeMilliseconds() + 3000
            end
        end
    end,
    BButtonDown = function()
        local s = Noble.currentScene()
        if not s then return end
        if s.zoomed then
            s.zoomed = false
            s:_update_dialog_for_cursor()
        else
            if s._return_scene then
                Noble.transition(s._return_scene)
            end
        end
    end
}

-- ============================================================
-- DRAW
-- ============================================================
local function draw_coin_cell(self, i)
    local id  = i - 1
    local col = (i - 1) % COLS
    local row = math.floor((i - 1) / COLS)
    local x   = GRID_X + col * (CELL_W + CELL_GAP_X)
    local y   = GRID_Y + row * (CELL_H + CELL_GAP_Y)

    gfx.drawRoundRect(x, y, CELL_W, CELL_H, 2)
    gfx.drawText(tostring(id), x + 2, y + 1)

    local img = (id < 4) and self.coin_imgs[id] or self.locked_img
    if id >= 4 then img = self.locked_img end
    if img then
        local iw = img:getSize()
        img:drawScaled(x + (CELL_W - 18) / 2, y + 3, 18 / iw)
    end

    local status = self:_coin_status(id)
    local label = (status == 'minted')    and 'MINTED'
               or (status == 'available') and 'AVAILABLE'
               or 'LOCKED'
    gfx.drawTextAligned(label, x + CELL_W / 2, y + CELL_H - 11,
                        kTextAlignment.center)

    if i == self.cursor then
        gfx.drawRoundRect(x - 2, y - 2, CELL_W + 4, CELL_H + 4, 3)
        gfx.drawRoundRect(x - 3, y - 3, CELL_W + 6, CELL_H + 6, 4)
    end
end

local function draw_top_bar()
    gfx.fillRect(0, 0, SCREEN_W, TOP_BAR_H)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawText("HAKCD > 23 C0iNS", 4, 0)
    gfx.fillTriangle(SCREEN_W - 12, 2, SCREEN_W - 4, 6, SCREEN_W - 12, 10)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

local function draw_sidebar(self)
    -- double vertical divider
    gfx.drawLine(SIDE_X - 1, 14, SIDE_X - 1, DIALOG_Y - 2)
    gfx.drawLine(SIDE_X,     14, SIDE_X,     DIALOG_Y - 2)

    gfx.drawText(string.format("MINTED: %d / 24", self:_minted_count()),
                 SIDE_INNER_X, 18)
    gfx.drawLine(SIDE_INNER_X, 32, SIDE_X + SIDE_W - 4, 32)

    gfx.drawText("STATUS:", SIDE_INNER_X, 36)

    local id = self:_coin_at(self.cursor)
    local c  = self._coin_by_id[id]
    local title = (c and c.title) or (id >= 4 and "???" or "LOCKED")
    gfx.drawText(title, SIDE_INNER_X, 48)
    gfx.drawLine(SIDE_INNER_X, 64, SIDE_X + SIDE_W - 4, 64)

    local closeup = self.coin_imgs_large[id] or self.locked_img
    if closeup then
        local iw = closeup:getSize()
        local target_w = 80
        local scale = target_w / iw
        local target_h = iw * scale  -- assume square; coin assets are 200x200
        local cx = SIDE_X + (SIDE_W - target_w) / 2
        local cy = 70
        -- starburst rays (4 short lines)
        gfx.drawLine(cx - 6,            cy + target_h / 2,   cx - 2,            cy + target_h / 2)
        gfx.drawLine(cx + target_w + 2, cy + target_h / 2,   cx + target_w + 6, cy + target_h / 2)
        gfx.drawLine(cx + target_w / 2, cy - 6,              cx + target_w / 2, cy - 2)
        gfx.drawLine(cx + target_w / 2, cy + target_h + 2,   cx + target_w / 2, cy + target_h + 6)
        closeup:drawScaled(cx, cy, scale)
    end

    gfx.drawTextInRect(
        "Solving the entire coin earns you the next coin regardless of solve status.",
        SIDE_INNER_X, 154, SIDE_W - 8, 20)

    gfx.drawText("X 23 C0iNS X", SIDE_INNER_X + 14, DIALOG_Y - 14)
end

local function draw_dialog_bar(self)
    gfx.drawRect(0, DIALOG_Y, SCREEN_W, DIALOG_H)
    gfx.drawRect(1, DIALOG_Y + 1, SCREEN_W - 2, DIALOG_H - 2)

    gfx.fillRect(2, DIALOG_Y + 2, 60, 12)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawText("newb", 6, DIALOG_Y + 2)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)

    gfx.drawLine(2, DIALOG_Y + 16, SCREEN_W - 2, DIALOG_Y + 16)

    if self.dialog_lines and self.dialog_lines[self.dialog_idx] then
        gfx.drawTextInRect(self.dialog_lines[self.dialog_idx],
            6, DIALOG_Y + 20, PORTRAIT_X - 12, DIALOG_H - 22)
    end

    gfx.drawRect(PORTRAIT_X, DIALOG_Y + 2, PORTRAIT_W, DIALOG_H - 4)
    if self._newb_img then
        local pw = self._newb_img:getSize()
        self._newb_img:draw(PORTRAIT_X + (PORTRAIT_W - pw) / 2, DIALOG_Y + 4)
    else
        gfx.drawTextAligned("newb", PORTRAIT_X + PORTRAIT_W / 2,
            DIALOG_Y + 30, kTextAlignment.center)
    end
end

function scene:drawBackground()
    scene.super.drawBackground(self)
    gfx.setColor(gfx.kColorBlack)

    draw_top_bar()

    if not self.zoomed then
        for i = 1, TOTAL_COINS do draw_coin_cell(self, i) end
    else
        local id = self:_coin_at(self.cursor)
        local closeup = self.coin_imgs_large[id] or self.locked_img
        if closeup then
            local iw = closeup:getSize()
            local target = math.min(150, SIDE_X - 30)
            local scale = target / iw
            closeup:drawScaled((SIDE_X - target) / 2,
                               20 + (140 - target) / 2, scale)
        end
        local cx, cy = SIDE_X / 2, 90
        gfx.drawLine(cx - 100, cy, cx - 85, cy)
        gfx.drawLine(cx + 85,  cy, cx + 100, cy)
        gfx.drawLine(cx, cy - 75, cx, cy - 60)
        gfx.drawLine(cx, cy + 60, cx, cy + 75)
    end

    draw_sidebar(self)
    draw_dialog_bar(self)
end
