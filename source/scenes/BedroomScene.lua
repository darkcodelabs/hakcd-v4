-- BedroomScene — LDtk-driven bedroom hub.
--
-- Loads levels/world.ldtk on init, materialises the "Bedroom" level on
-- enter() via LDtk.create_tilemap(), and spawns a Newb sprite at the
-- player_spawn entity. Hotspot entities become invisible trigger sprites
-- whose collide-rects newb walks over; the active hotspot id is displayed
-- in a bottom-of-screen prompt strip.
--
-- A-press currently prints the hotspot id. Agent 4 (PORT) replaces that
-- block with NobleScene.transitionTo(LockpickScene) etc. — the mapping
-- between hotspot_id and target scene lives there, not here.

import 'libraries/noble/Noble'

BedroomScene = {}
class('BedroomScene').extends(NobleScene)

BedroomScene.backgroundColor = playdate.graphics.kColorWhite

local LEVEL_NAME = 'Bedroom'

-- Phase 14 perf fix #3: cache tilemap + empty-tile-ID + entity lookups at
-- module scope so re-entering Bedroom from a modal (Computer/Modem/Phone/
-- Playground) doesn't rebuild LDtk structures. Noble instantiates a fresh
-- scene per transition (`queuedScene = NewScene(...)`), so init() runs
-- per-entry — module-level cache is the only place these are paid once.
local _level_built       = false
local _cached_layer_meta = nil  -- list of { name, tilemap, empty_ids, z }
local _cached_entities   = nil  -- LDtk.get_entities(LEVEL_NAME)

local function _build_level_caches()
    if _level_built then return end
    local layers = LDtk.get_layers(LEVEL_NAME) or {}
    _cached_layer_meta = {}
    for layerName, layer in pairs(layers) do
        if layer.tiles then
            local tm = LDtk.create_tilemap(LEVEL_NAME, layerName)
            if tm then
                local empty = LDtk.get_empty_tileIDs(LEVEL_NAME, 'Solid', layerName)
                local z = (layerName == 'Foreground') and 10 or 0
                table.insert(_cached_layer_meta, {
                    name      = layerName,
                    tilemap   = tm,
                    empty_ids = empty,
                    z         = z,
                })
            end
        end
    end
    _cached_entities = LDtk.get_entities(LEVEL_NAME)
    _level_built = true
end

function BedroomScene:init()
    BedroomScene.super.init(self)
    -- LDtk.load() caches all level data globally; safe to call repeatedly,
    -- but it re-parses the JSON every time, so we gate on a sentinel.
    if not _G._hakcd_ldtk_loaded then
        LDtk.load('levels/world.ldtk')
        _G._hakcd_ldtk_loaded = true
    end
    -- Build (or no-op if already built) the tilemap + entity caches.
    -- Sprites themselves are NOT cached here — Noble's finish() removes
    -- the previous scene's sprites at transition midpoint, so we have to
    -- re-create the sprite shells per enter. But the heavy tilemap and
    -- entity-table builds are now paid once.
    _build_level_caches()
end

function BedroomScene:enter(previousScene)
    BedroomScene.super.enter(self, previousScene)

    if _G.sound_manifest and _G.sound_manifest.start_scene_music then
        _G.sound_manifest.start_scene_music('BedroomScene')
    end

    local gfx = playdate.graphics

    -- Build per-enter sprite shells from the cached tilemap meta. Cheap:
    -- sprite.new() + setTilemap(cached) + addWallSprites(cached).
    for _, meta in ipairs(_cached_layer_meta) do
        local layerSprite = gfx.sprite.new()
        layerSprite:setTilemap(meta.tilemap)
        layerSprite:setCenter(0, 0)
        layerSprite:moveTo(0, 0)
        layerSprite:setZIndex(meta.z)
        layerSprite:add()
        if meta.empty_ids then
            gfx.sprite.addWallSprites(meta.tilemap, meta.empty_ids)
        end
        if meta.name == 'Background' then self.bgSprite = layerSprite end
        if meta.name == 'Foreground' then self.fgSprite = layerSprite end
        self.tilemap = self.tilemap or meta.tilemap
    end

    -- Spawn the newb at player_spawn entity if defined, else fall back to
    -- the canonical default spawn point in rooms.sc01 (rooms.lua manifest,
    -- Phase 6). LDtk entity wins over manifest — manifest is the floor.
    local sc01 = rooms_manifest and rooms_manifest.sc01
    local sc01_spawn = sc01 and sc01.spawn_points and sc01.spawn_points[1]
    local spawnX = (sc01_spawn and sc01_spawn.x) or 200
    local spawnY = (sc01_spawn and sc01_spawn.y) or 168
    -- The importer attaches entities to the layer that contains them.
    -- We look for the player_spawn entity by name across all entity layers.
    local all = _cached_entities
    if all then
        for _, ent in ipairs(all) do
            if ent.name == 'player_spawn' then
                spawnX = ent.position.x
                spawnY = ent.position.y
                break
            end
        end
    end

    -- Try to spawn Agent 2's Newb sprite. If it doesn't exist yet we fall
    -- back to a 16x16 fillRect block so this scene still loads.
    if _G.Newb then
        self.newb = Newb(spawnX, spawnY)
    else
        local stand = gfx.sprite.new()
        local img = gfx.image.new(16, 24, gfx.kColorBlack)
        stand:setImage(img)
        stand:moveTo(spawnX, spawnY)
        stand:setCollideRect(0, 0, 16, 24)
        stand:setZIndex(100)
        stand:add()
        stand.updateMovement = function(this)
            local pd <const> = playdate
            local SPEED = 3
            local dx, dy = 0, 0
            if pd.buttonIsPressed(pd.kButtonLeft)  then dx = -SPEED end
            if pd.buttonIsPressed(pd.kButtonRight) then dx =  SPEED end
            if pd.buttonIsPressed(pd.kButtonUp)    then dy = -SPEED end
            if pd.buttonIsPressed(pd.kButtonDown)  then dy =  SPEED end
            if dx ~= 0 or dy ~= 0 then
                this:moveWithCollisions(this.x + dx, this.y + dy)
            end
        end
        self.newb = stand
    end

    -- Hotspot trigger sprites. Walk over -> activeHotspot is set. Walks
    -- the cached entity list rather than re-querying LDtk per enter.
    self.hotspots = {}
    local hsList = _cached_entities or {}
    for _, ent in ipairs(hsList) do
        if ent.name == 'Hotspot' then
            local hs = gfx.sprite.new()
            local w = (ent.size and ent.size.width)  or 24
            local h = (ent.size and ent.size.height) or 24
            hs:setSize(w, h)
            hs:setCenter(0, 0)
            hs:moveTo(ent.position.x, ent.position.y)
            hs:setCollideRect(0, 0, w, h)
            hs:setVisible(false)
            hs.hotspot_id = ent.fields.hotspot_id
            hs.label      = ent.fields.label or ent.fields.hotspot_id
            hs.tier       = ent.fields.tier  or 1
            hs:add()
            table.insert(self.hotspots, hs)
        end
    end

    self.activeHotspot = nil
end

function BedroomScene:update()
    BedroomScene.super.update(self)
    if self.newb and self.newb.updateMovement then
        self.newb:updateMovement()
    end

    -- Phase 14 perf fix #5: replace per-frame `self.newb:overlappingSprites()`
    -- (which the SDK returns as a fresh Lua table each call) with manual
    -- rect-intersection against our cached self.hotspots list. Zero
    -- per-frame allocation. Sprite bounds are pulled directly off the
    -- sprite without going through getBoundsRect()'s playdate.geometry
    -- allocator.
    local active = nil
    if self.newb and self.hotspots then
        local nx, ny = self.newb.x, self.newb.y
        local nw, nh = self.newb.width or 32, self.newb.height or 32
        -- Newb sprite uses default center (0.5, 0.5) per AnimatedSprite,
        -- so x/y are the CENTER. Translate to top-left for rect math.
        local nl, nt = nx - nw / 2, ny - nh / 2
        local nr, nb = nl + nw, nt + nh
        for i = 1, #self.hotspots do
            local hs = self.hotspots[i]
            -- Hotspots use setCenter(0,0) so hs.x/y are TOP-LEFT.
            local hl, ht = hs.x, hs.y
            local hr, hb = hl + (hs.width or 24), ht + (hs.height or 24)
            if nl < hr and nr > hl and nt < hb and nb > ht then
                if hs.hotspot_id then active = hs; break end
            end
        end
    end
    self.activeHotspot = active

    -- A-press: route bedroom hotspots to the right scene / dialog.
    -- Hotspot id contract lives in canon.lua (canon.objects.<id>); this
    -- block must never compare against a bare string literal. Bed is the
    -- only non-modal — it uses transitions_to (sleep hop), the others use
    -- launches (modal). Phase 11: every dispatch now flows through
    -- SceneRouter.transition_by_id so the canon-id -> class lookup +
    -- validation happens in one place.
    if playdate.buttonJustPressed(playdate.kButtonA) and self.activeHotspot then
        local id = self.activeHotspot.hotspot_id
        if id == canon.objects.bed.id then
            SceneRouter.transition_by_id(canon.objects.bed.transitions_to)
        elseif id == canon.objects.computer.id then
            SceneRouter.transition_by_id(canon.objects.computer.launches)
        elseif id == canon.objects.modem.id then
            SceneRouter.transition_by_id(canon.objects.modem.launches)
        elseif id == canon.objects.phone.id then
            SceneRouter.transition_by_id(canon.objects.phone.launches)
        else
            self._dialog_text = '[placeholder] ' .. tostring(id)
            self._dialog_until_ms = playdate.getCurrentTimeMilliseconds() + 2200
        end
    end
    if self._dialog_until_ms and playdate.getCurrentTimeMilliseconds() > self._dialog_until_ms then
        self._dialog_text = nil
        self._dialog_until_ms = nil
    end
end

function BedroomScene:drawForeground()
    BedroomScene.super.drawForeground(self)
    local gfx = playdate.graphics
    if self.activeHotspot then
        gfx.fillRect(0, 220, 400, 20)
        gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        gfx.drawText('[A] ' .. self.activeHotspot.label, 8, 224)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
    if self._dialog_text then
        gfx.fillRect(0, 200, 400, 18)
        gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        gfx.drawText(self._dialog_text, 8, 203)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
end
