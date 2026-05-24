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

function BedroomScene:init()
    BedroomScene.super.init(self)
    -- LDtk.load() caches all level data globally; safe to call repeatedly,
    -- but it re-parses the JSON every time, so we gate on a sentinel.
    if not _G._hakcd_ldtk_loaded then
        LDtk.load('levels/world.ldtk')
        _G._hakcd_ldtk_loaded = true
    end
end

function BedroomScene:enter(previousScene)
    BedroomScene.super.enter(self, previousScene)

    local gfx = playdate.graphics

    -- Walk each tile layer in the LDtk level explicitly so we never depend on
    -- pairs() ordering for what becomes the "main" tilemap. Background sits
    -- at zIndex 0, Foreground at 10. Both layers contribute solid tiles to
    -- the collision system via addWallSprites — empty tile ids per layer are
    -- looked up from the LDtk Solid enum tag.
    local layers = LDtk.get_layers(LEVEL_NAME) or {}
    for layerName, layer in pairs(layers) do
        if layer.tiles then
            local tm = LDtk.create_tilemap(LEVEL_NAME, layerName)
            if tm then
                local layerSprite = gfx.sprite.new()
                layerSprite:setTilemap(tm)
                layerSprite:setCenter(0, 0)
                layerSprite:moveTo(0, 0)
                local z = (layerName == 'Foreground') and 10 or 0
                layerSprite:setZIndex(z)
                layerSprite:add()
                local empty = LDtk.get_empty_tileIDs(LEVEL_NAME, 'Solid', layerName)
                if empty then
                    gfx.sprite.addWallSprites(tm, empty)
                end
                if layerName == 'Background' then self.bgSprite = layerSprite end
                if layerName == 'Foreground' then self.fgSprite = layerSprite end
                self.tilemap = self.tilemap or tm
            end
        end
    end

    -- Spawn the newb at player_spawn entity if defined, else mid-room.
    local spawnX, spawnY = 200, 168
    local spawns = LDtk.get_entities(LEVEL_NAME, 'Hotspots') -- check all layers
    -- The importer attaches entities to the layer that contains them.
    -- We look for the player_spawn entity by name across all entity layers.
    local all = LDtk.get_entities(LEVEL_NAME)
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

    -- Hotspot trigger sprites. Walk over -> activeHotspot is set.
    self.hotspots = {}
    local hsList = LDtk.get_entities(LEVEL_NAME, 'Hotspots') or {}
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

    -- Hotspot overlap detect — find which hotspot trigger newb overlaps.
    local active = nil
    if self.newb then
        local overlapping = self.newb:overlappingSprites()
        for _, s in ipairs(overlapping) do
            if s.hotspot_id then active = s; break end
        end
    end
    self.activeHotspot = active

    -- A-press: route bedroom hotspots to the right scene / dialog.
    -- Hotspot id contract (per Agent 3's LDtk authoring):
    --   bed       -> sleep (transition to PlaygroundScene as the morning hop)
    --   computer  -> BedroomComputer dialog (placeholder for now)
    --   modem     -> placeholder dialog
    --   phone     -> placeholder dialog
    if playdate.buttonJustPressed(playdate.kButtonA) and self.activeHotspot then
        local id = self.activeHotspot.hotspot_id
        if id == 'bed' then
            Noble.transition(PlaygroundScene)
        elseif id == 'computer' then
            self._dialog_text = 'computer: SignalNet boots... [placeholder]'
            self._dialog_until_ms = playdate.getCurrentTimeMilliseconds() + 2500
        elseif id == 'modem' then
            self._dialog_text = 'modem: 2400 baud ready. [placeholder]'
            self._dialog_until_ms = playdate.getCurrentTimeMilliseconds() + 2500
        elseif id == 'phone' then
            self._dialog_text = 'phone: line dead. [placeholder]'
            self._dialog_until_ms = playdate.getCurrentTimeMilliseconds() + 2500
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
