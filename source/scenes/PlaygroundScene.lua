-- PlaygroundScene — LDtk-driven PWNGLOVE playground.
--
-- Mirrors BedroomScene exactly except for the level name. Tier-1 hotspots
-- (lockpick_station, tyson_cabinet, coin_vault) plus tier-2/3 stubs for
-- payphone + portal_pedestal are read straight out of the LDtk world file.
-- Agent 4 wires the real interaction targets.

import 'libraries/noble/Noble'

PlaygroundScene = {}
class('PlaygroundScene').extends(NobleScene)

PlaygroundScene.backgroundColor = playdate.graphics.kColorWhite

local LEVEL_NAME = 'Playground'

function PlaygroundScene:init()
    PlaygroundScene.super.init(self)
    if not _G._hakcd_ldtk_loaded then
        LDtk.load('levels/world.ldtk')
        _G._hakcd_ldtk_loaded = true
    end
end

function PlaygroundScene:enter(previousScene)
    PlaygroundScene.super.enter(self, previousScene)

    if _G.sound_manifest and _G.sound_manifest.start_scene_music then
        _G.sound_manifest.start_scene_music('PlaygroundScene')
    end

    local gfx = playdate.graphics

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

    -- Default spawn comes from rooms.playground.spawn_points[1] (rooms.lua
    -- manifest). LDtk player_spawn entity wins over manifest — manifest is
    -- the floor so the room is playable even if LDtk authoring lapses.
    local pg = rooms_manifest and rooms_manifest.playground
    local pg_spawn = pg and pg.spawn_points and pg.spawn_points[1]
    local spawnX = (pg_spawn and pg_spawn.x) or 200
    local spawnY = (pg_spawn and pg_spawn.y) or 168
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

function PlaygroundScene:update()
    PlaygroundScene.super.update(self)
    if self.newb and self.newb.updateMovement then
        self.newb:updateMovement()
    end

    local active = nil
    if self.newb then
        local overlapping = self.newb:overlappingSprites()
        for _, s in ipairs(overlapping) do
            if s.hotspot_id then active = s; break end
        end
    end
    self.activeHotspot = active

    -- A-press: route playground hotspots to the right minigame scene.
    -- Hotspot ids + scene targets are read from canon.objects.<id>; this
    -- block must never compare against a bare string literal. The three
    -- tier-1 hotspots have launches set (LockpickScene / TysonScene /
    -- CoinVaultScene); the six tier-2/3 placeholders (rfid_pedestal /
    -- payphone / ir_wall / gravity_arena / subghz_tuner / portal_pedestal)
    -- have launches=nil and fall into the else branch. Each minigame is
    -- told to come back to PlaygroundScene via return_scene. Phase 11:
    -- dispatch goes through SceneRouter.transition_by_id so the canon-id
    -- lookup + class resolution + missing-class warning all happen once
    -- in one place. We still pass return_scene as the args payload so the
    -- minigame's exit path can Noble.transition straight back.
    if playdate.buttonJustPressed(playdate.kButtonA) and self.activeHotspot then
        local id = self.activeHotspot.hotspot_id
        local launch_args = { return_scene = PlaygroundScene }
        if id == canon.objects.lockpick_station.id then
            SceneRouter.transition_by_id(canon.objects.lockpick_station.launches, launch_args)
        elseif id == canon.objects.tyson_cabinet.id then
            SceneRouter.transition_by_id(canon.objects.tyson_cabinet.launches, launch_args)
        elseif id == canon.objects.coin_vault.id then
            SceneRouter.transition_by_id(canon.objects.coin_vault.launches, launch_args)
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

function PlaygroundScene:drawForeground()
    PlaygroundScene.super.drawForeground(self)
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
