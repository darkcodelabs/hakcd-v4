#!/usr/bin/env node
// build_world_ldtk.js — emit source/levels/world.ldtk
//
// HAKCD v4 world file generator. The NicMagnier LDtk importer parses the
// LDtk v1.5.x JSON schema. Hand-writing 2k+ lines of JSON is brittle, so we
// build the structure programmatically here and write a single non-external
// world.ldtk (externalLevels: false) — that is the simpler shape the Playdate
// importer can consume without a sidecar folder of .ldtkl files.
//
// Coordinate model
//   tile size       : 24px (matches hakcd-table-24-24.png)
//   level dims      : 17 wide x 10 tall tiles  -> 408x240 px
//                     (slightly wider than Playdate 400x240 so right wall
//                      tiles render flush at the edge)
//
// Tile index map matches build_tileset.sh — see that file for the canonical
// numbering. We refer to tiles via TILE.<name> below.
//
// Layer order matters: LDtk renders layerInstances in REVERSE — first entry
// drawn last (on top). We emit Hotspots > Foreground > Background > Collision
// so Background renders at the bottom, Foreground on top of it, Hotspots are
// invisible triggers, and Collision (IntGrid) is non-visual.

const fs = require('node:fs');
const path = require('node:path');

// ---------------------------------------------------------------------------
// constants
// ---------------------------------------------------------------------------
const TILE = 24;
const LVL_W = 17; // tiles
const LVL_H = 10; // tiles
const PX_W = LVL_W * TILE; // 408
const PX_H = LVL_H * TILE; // 240
const TILESET_PX = 192;     // 8x8 grid of 24px cells
const TILESET_GW = TILESET_PX / TILE; // 8 cells wide

// tile ids (linear index into the 8x8 tileset, row-major, 0-based)
const T = {
    EMPTY:         0,
    WOOD_FLOOR:    1,
    CARPET:        2,
    CONCRETE:      3,
    BRICK_FLOOR:   4,
    WINDOW:        5,
    PHONE:         6,    // rotary phone
    FLOPPY:        7,
    BRICK_LT:      8,
    BRICK_DK:      9,
    PLASTER:      10,
    METAL:        11,
    CORNER_TL:    12,
    CORNER_TR:    13,
    EDGE_TOP:     14,
    WALL_CTR:     15,
    CORNER_BL:    16,
    CORNER_BR:    17,
    EDGE_BOT:     18,
    EDGE_L:       19,
    EDGE_R:       20,
    DOOR_CLOSED:  21,
    DOOR_OPEN:    22,
    MODEM:        23,
    BED_TOP:      24,
    BED_BOT:      25,
    COMPUTER_CRT: 26,
    COMPUTER_TWR: 27,
    BENCH_L:      28,
    BENCH_R:      29,
    PAYPHONE:     30,
    CRT_TV:       31,
    SERVER_RACK:  32,
    ARCADE_TOP:   33,
    ARCADE_BOT:   34,
    COIN_VAULT:   35,
    PORTAL:       36,
    WINDOW_CRK:   37,
    DESK_L:       38,
    DESK_R:       39,
};

// uids — must be globally unique within the .ldtk file
const UID = {
    TILESET:        1,
    ENUM_TILE_TAG:  2,
    LAYER_BG:       10,
    LAYER_FG:       11,
    LAYER_HOTSPOTS: 12,
    LAYER_COLLIDE:  13,
    ENTITY_HOTSPOT: 20,
    ENTITY_SPAWN:   21,
    FIELD_HS_ID:    30,
    FIELD_HS_TIER:  31,
    FIELD_HS_LABEL: 32,
    FIELD_HS_TOOL:  33,
    LEVEL_BEDROOM:  100,
    LEVEL_PG:       101,
};

// solid tile ids — tagged in the enum so addWallSprites() finds them
const SOLID_IDS = [
    T.BRICK_LT, T.BRICK_DK, T.PLASTER, T.METAL,
    T.CORNER_TL, T.CORNER_TR, T.CORNER_BL, T.CORNER_BR,
    T.EDGE_TOP, T.EDGE_BOT, T.EDGE_L, T.EDGE_R, T.WALL_CTR,
    T.BED_TOP, T.BED_BOT,
    T.COMPUTER_CRT, T.COMPUTER_TWR,
    T.BENCH_L, T.BENCH_R,
    T.PAYPHONE, T.CRT_TV, T.SERVER_RACK,
    T.ARCADE_TOP, T.ARCADE_BOT,
    T.COIN_VAULT, T.PORTAL,
    T.DESK_L, T.DESK_R,
    T.DOOR_CLOSED,
    T.MODEM,
];
const INTERACTIVE_IDS = [
    T.COMPUTER_CRT, T.COMPUTER_TWR, T.PHONE, T.MODEM,
    T.PAYPHONE, T.BENCH_L, T.BENCH_R, T.ARCADE_TOP, T.ARCADE_BOT,
    T.COIN_VAULT, T.PORTAL, T.DOOR_CLOSED, T.DOOR_OPEN, T.BED_TOP, T.BED_BOT,
];

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

// LDtk requires unique iids (32-char hex with hyphens). For determinism we
// derive them from a counter rather than randomness — that way diffs are
// stable across regenerations.
let _iidCounter = 0;
function nextIid() {
    _iidCounter += 1;
    const hex = _iidCounter.toString(16).padStart(8, '0');
    return `${hex}-1111-2222-3333-444455556666`;
}

// Convert tile id -> src pixel coords in the tileset image.
function tileSrc(id) {
    const col = id % TILESET_GW;
    const row = Math.floor(id / TILESET_GW);
    return [col * TILE, row * TILE];
}

// Build the gridTiles array entry for a tile placed at (col, row) of tile id.
function gridTile(col, row, id) {
    const px = [col * TILE, row * TILE];
    const src = tileSrc(id);
    const d = row * LVL_W + col; // tile data index expected by the importer
    return { px, src, f: 0, t: id, d: [d] };
}

// Build an entity instance
function entityInstance({ identifier, defUid, col, row, w, h, fields, pivot }) {
    pivot = pivot || [0, 0];
    return {
        __identifier: identifier,
        __grid: [col, row],
        __pivot: pivot,
        __tags: [],
        __tile: null,
        __smartColor: "#FFFFFF",
        iid: nextIid(),
        width: w,
        height: h,
        defUid,
        px: [col * TILE, row * TILE],
        fieldInstances: fields || [],
        __worldX: col * TILE,
        __worldY: row * TILE,
    };
}

function hotspotEntity({ id, label, tier, col, row, w, h, tool }) {
    const fields = [
        { __identifier: "hotspot_id", __type: "String", __value: id,    __tile: null, defUid: UID.FIELD_HS_ID,    realEditorValues: [] },
        { __identifier: "tier",       __type: "Int",    __value: tier,  __tile: null, defUid: UID.FIELD_HS_TIER,  realEditorValues: [] },
        { __identifier: "label",      __type: "String", __value: label, __tile: null, defUid: UID.FIELD_HS_LABEL, realEditorValues: [] },
        { __identifier: "tool_required", __type: "String", __value: tool || null, __tile: null, defUid: UID.FIELD_HS_TOOL, realEditorValues: [] },
    ];
    return entityInstance({
        identifier: "Hotspot",
        defUid: UID.ENTITY_HOTSPOT,
        col, row, w: w || TILE, h: h || TILE, fields,
        pivot: [0, 0],
    });
}

function spawnEntity({ col, row }) {
    return entityInstance({
        identifier: "player_spawn",
        defUid: UID.ENTITY_SPAWN,
        col, row, w: TILE, h: TILE, fields: [],
        pivot: [0, 0],
    });
}

// Build an empty intGridCsv of LVL_W * LVL_H zeros
function emptyIntGrid() { return new Array(LVL_W * LVL_H).fill(0); }

// ---------------------------------------------------------------------------
// background tile maps — wood/carpet/concrete + perimeter walls
// ---------------------------------------------------------------------------
function buildBgTiles(opts) {
    const tiles = [];
    for (let r = 0; r < LVL_H; r += 1) {
        for (let c = 0; c < LVL_W; c += 1) {
            let id;
            // wall perimeter
            if (r === 0 && c === 0) id = T.CORNER_TL;
            else if (r === 0 && c === LVL_W - 1) id = T.CORNER_TR;
            else if (r === LVL_H - 1 && c === 0) id = T.CORNER_BL;
            else if (r === LVL_H - 1 && c === LVL_W - 1) id = T.CORNER_BR;
            else if (r === 0)            id = T.EDGE_TOP;
            else if (r === LVL_H - 1)    id = T.EDGE_BOT;
            else if (c === 0)            id = T.EDGE_L;
            else if (c === LVL_W - 1)    id = T.EDGE_R;
            else                         id = opts.floor;
            tiles.push(gridTile(c, r, id));
        }
    }
    // overlay window(s)
    for (const w of (opts.windows || [])) {
        // overwrite the tile at that grid pos
        const idx = w.r * LVL_W + w.c;
        tiles[idx] = gridTile(w.c, w.r, w.id || T.WINDOW);
    }
    return tiles;
}

// build the collision IntGrid (1 = solid) — perimeter walls + furniture
function buildCollision(furnitureCells) {
    const grid = emptyIntGrid();
    for (let r = 0; r < LVL_H; r += 1) {
        for (let c = 0; c < LVL_W; c += 1) {
            if (r === 0 || c === 0 || r === LVL_H - 1 || c === LVL_W - 1) {
                grid[r * LVL_W + c] = 1;
            }
        }
    }
    for (const fc of furnitureCells) {
        grid[fc.r * LVL_W + fc.c] = 1;
    }
    return grid;
}

// ---------------------------------------------------------------------------
// Bedroom level (17x10)
// ---------------------------------------------------------------------------
// Layout (skipping outer walls):
//   row 2-3 col 2-3 : bed (top + bot)
//   row 2   col 12-13: desk top + computer CRT
//   row 3   col 12-13: desk bot + computer tower
//   row 4   col 13   : modem
//   row 5   col 2    : rotary phone (mounted on left wall)
//   window at row 1 col 8 (top wall break)
//
// Hotspots:
//   computer @ col 12 row 2 (covers computer + desk)
//   modem    @ col 13 row 4
//   phone    @ col 2  row 5
//   bed      @ col 2  row 2 (covers both bed tiles)
//
// player_spawn @ col 8 row 7 (middle of room near bottom)
function buildBedroom() {
    const bg = buildBgTiles({
        floor: T.WOOD_FLOOR,
        windows: [{ c: 8, r: 0, id: T.WINDOW }],
    });

    // foreground tiles (furniture)
    const fgPlacements = [
        // bed
        { c: 2, r: 2, id: T.BED_TOP },
        { c: 2, r: 3, id: T.BED_BOT },
        // desk + computer
        { c: 12, r: 2, id: T.DESK_L },
        { c: 13, r: 2, id: T.DESK_R },
        { c: 12, r: 3, id: T.COMPUTER_TWR },
        { c: 13, r: 3, id: T.COMPUTER_CRT },
        // modem on desk side
        { c: 13, r: 4, id: T.MODEM },
        // rotary phone mounted on left wall
        { c: 2, r: 5, id: T.PHONE },
        // a floppy on the floor for flavour
        { c: 9, r: 6, id: T.FLOPPY },
    ];
    const fg = fgPlacements.map(p => gridTile(p.c, p.r, p.id));

    const collision = buildCollision([
        { c: 2, r: 2 }, { c: 2, r: 3 }, // bed
        { c: 12, r: 2 }, { c: 13, r: 2 }, // desk
        { c: 12, r: 3 }, { c: 13, r: 3 }, // computer
        { c: 13, r: 4 }, // modem
        // phone is interactive but not a movement blocker — newb can stand
        // under it
    ]);

    const entities = [
        hotspotEntity({ id: 'computer', label: 'USE COMPUTER', tier: 1, col: 12, row: 2, w: TILE * 2, h: TILE * 2 }),
        hotspotEntity({ id: 'modem',    label: 'USE MODEM',    tier: 1, col: 13, row: 4, w: TILE,     h: TILE }),
        hotspotEntity({ id: 'phone',    label: 'CALL MOM',     tier: 1, col: 2,  row: 5, w: TILE,     h: TILE }),
        hotspotEntity({ id: 'bed',      label: 'SLEEP',        tier: 1, col: 2,  row: 2, w: TILE,     h: TILE * 2 }),
        spawnEntity({ col: 8, row: 7 }),
    ];

    return { bg, fg, collision, entities };
}

// ---------------------------------------------------------------------------
// Playground level (17x10) — concrete floor, 3 tier-1 stations
//
// row 2 col 2-3   : workbench (lockpick station)
// row 2 col 7-8   : arcade cabinet (top)
// row 3 col 7-8   : arcade cabinet (bot)
// row 2 col 13    : coin vault pedestal
// row 5 col 4     : payphone (stub for tier 2)
// row 5 col 10    : portal pedestal (stub for tier 3)
// row 5 col 13    : server rack (stub flavour)
// player_spawn col 8 row 7
function buildPlayground() {
    const bg = buildBgTiles({
        floor: T.CONCRETE,
        windows: [{ c: 4, r: 0, id: T.WINDOW_CRK }],
    });

    const fgPlacements = [
        // workbench (lockpick station)
        { c: 2, r: 2, id: T.BENCH_L },
        { c: 3, r: 2, id: T.BENCH_R },
        // arcade cabinet
        { c: 7, r: 2, id: T.ARCADE_TOP },
        { c: 7, r: 3, id: T.ARCADE_BOT },
        { c: 8, r: 2, id: T.ARCADE_TOP },
        { c: 8, r: 3, id: T.ARCADE_BOT },
        // coin vault
        { c: 13, r: 2, id: T.COIN_VAULT },
        // payphone (tier-2 stub)
        { c: 4, r: 5, id: T.PAYPHONE },
        // portal pedestal (tier-3 stub)
        { c: 10, r: 5, id: T.PORTAL },
        // server rack flavour
        { c: 13, r: 5, id: T.SERVER_RACK },
        // CRT TV
        { c: 13, r: 6, id: T.CRT_TV },
    ];
    const fg = fgPlacements.map(p => gridTile(p.c, p.r, p.id));

    const collision = buildCollision([
        { c: 2, r: 2 }, { c: 3, r: 2 }, // bench
        { c: 7, r: 2 }, { c: 7, r: 3 }, // arcade L
        { c: 8, r: 2 }, { c: 8, r: 3 }, // arcade R
        { c: 13, r: 2 }, // vault
        { c: 4, r: 5 }, // payphone
        { c: 10, r: 5 }, // portal
        { c: 13, r: 5 }, // server
        { c: 13, r: 6 }, // tv
    ]);

    const entities = [
        hotspotEntity({ id: 'lockpick_station', label: 'LOCKPICK', tier: 1, col: 2,  row: 2, w: TILE * 2, h: TILE }),
        hotspotEntity({ id: 'tyson_cabinet',    label: 'TYSON',    tier: 1, col: 7,  row: 2, w: TILE * 2, h: TILE * 2 }),
        hotspotEntity({ id: 'coin_vault',       label: 'VAULT',    tier: 1, col: 13, row: 2, w: TILE,     h: TILE }),
        // tier-2/3 stubs — included so Agent 4 can wire later
        hotspotEntity({ id: 'payphone',         label: 'PAYPHONE', tier: 2, col: 4,  row: 5, w: TILE, h: TILE }),
        hotspotEntity({ id: 'portal_pedestal',  label: 'PORTAL',   tier: 3, col: 10, row: 5, w: TILE, h: TILE }),
        spawnEntity({ col: 8, row: 7 }),
    ];

    return { bg, fg, collision, entities };
}

// ---------------------------------------------------------------------------
// layer instance builders
// ---------------------------------------------------------------------------
function layerTiles({ identifier, uid, tiles }) {
    return {
        __identifier: identifier,
        __type: "Tiles",
        __cWid: LVL_W,
        __cHei: LVL_H,
        __gridSize: TILE,
        __opacity: 1,
        __pxTotalOffsetX: 0,
        __pxTotalOffsetY: 0,
        __tilesetDefUid: UID.TILESET,
        __tilesetRelPath: "../images/tilesets/hakcd-table-24-24.png",
        iid: nextIid(),
        levelId: 0,
        layerDefUid: uid,
        pxOffsetX: 0,
        pxOffsetY: 0,
        visible: true,
        optionalRules: [],
        intGridCsv: [],
        autoLayerTiles: [],
        seed: 1,
        overrideTilesetUid: null,
        gridTiles: tiles,
        entityInstances: [],
    };
}

function layerEntities({ identifier, uid, entities }) {
    return {
        __identifier: identifier,
        __type: "Entities",
        __cWid: LVL_W,
        __cHei: LVL_H,
        __gridSize: TILE,
        __opacity: 1,
        __pxTotalOffsetX: 0,
        __pxTotalOffsetY: 0,
        __tilesetDefUid: null,
        __tilesetRelPath: null,
        iid: nextIid(),
        levelId: 0,
        layerDefUid: uid,
        pxOffsetX: 0,
        pxOffsetY: 0,
        visible: true,
        optionalRules: [],
        intGridCsv: [],
        autoLayerTiles: [],
        seed: 1,
        overrideTilesetUid: null,
        gridTiles: [],
        entityInstances: entities,
    };
}

function layerIntGrid({ identifier, uid, csv }) {
    return {
        __identifier: identifier,
        __type: "IntGrid",
        __cWid: LVL_W,
        __cHei: LVL_H,
        __gridSize: TILE,
        __opacity: 1,
        __pxTotalOffsetX: 0,
        __pxTotalOffsetY: 0,
        __tilesetDefUid: null,
        __tilesetRelPath: null,
        iid: nextIid(),
        levelId: 0,
        layerDefUid: uid,
        pxOffsetX: 0,
        pxOffsetY: 0,
        visible: false,
        optionalRules: [],
        intGridCsv: csv,
        autoLayerTiles: [],
        seed: 1,
        overrideTilesetUid: null,
        gridTiles: [],
        entityInstances: [],
    };
}

function buildLevel({ identifier, iidString, uid, worldX, worldY, payload }) {
    return {
        identifier,
        iid: iidString,
        uid,
        worldX,
        worldY,
        worldDepth: 0,
        pxWid: PX_W,
        pxHei: PX_H,
        __bgColor: "#FFFFFF",
        bgColor: "#FFFFFF",
        useAutoIdentifier: false,
        bgRelPath: null,
        bgPos: null,
        bgPivotX: 0.5,
        bgPivotY: 0.5,
        __smartColor: "#FFFFFF",
        __bgPos: null,
        externalRelPath: null,
        fieldInstances: [],
        layerInstances: [
            // Order matters: first = TOP. We want Hotspots & Foreground on top
            // of Background, but Collision is invisible so order doesn't affect
            // visuals — we still put it last for clarity.
            layerEntities({ identifier: "Hotspots",   uid: UID.LAYER_HOTSPOTS, entities: payload.entities }),
            layerTiles({   identifier: "Foreground", uid: UID.LAYER_FG,       tiles: payload.fg }),
            layerTiles({   identifier: "Background", uid: UID.LAYER_BG,       tiles: payload.bg }),
            layerIntGrid({ identifier: "Collision",   uid: UID.LAYER_COLLIDE,  csv: payload.collision }),
        ],
        __neighbours: [],
    };
}

// ---------------------------------------------------------------------------
// top-level project
// ---------------------------------------------------------------------------
function build() {
    const bedroom = buildBedroom();
    const playground = buildPlayground();

    const bedroomIid    = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
    const playgroundIid = "aaaaaaab-bbbb-cccc-dddd-eeeeeeeeeeee";

    const tilesetDef = {
        __cWid: TILESET_GW,                       // 8
        __cHei: TILESET_PX / TILE,                // 8
        identifier: "Hakcd",
        uid: UID.TILESET,
        relPath: "../images/tilesets/hakcd-table-24-24.png",
        embedAtlas: null,
        pxWid: TILESET_PX,
        pxHei: TILESET_PX,
        tileGridSize: TILE,
        spacing: 0,
        padding: 0,
        tags: [],
        tagsSourceEnumUid: UID.ENUM_TILE_TAG,
        enumTags: [
            { enumValueId: "Solid",       tileIds: SOLID_IDS },
            { enumValueId: "Interactive", tileIds: INTERACTIVE_IDS },
        ],
        customData: [],
        savedSelections: [],
        cachedPixelData: {},
    };

    const layerDefs = [
        // Tiles layers
        {
            __type: "Tiles", identifier: "Background", type: "Tiles", uid: UID.LAYER_BG,
            doc: null, uiColor: null, gridSize: TILE,
            guideGridWid: 0, guideGridHei: 0,
            displayOpacity: 1, inactiveOpacity: 0.6, hideInList: false,
            hideFieldsWhenInactive: true, canSelectWhenInactive: true, renderInWorldView: true,
            pxOffsetX: 0, pxOffsetY: 0, parallaxFactorX: 0, parallaxFactorY: 0, parallaxScaling: true,
            requiredTags: [], excludedTags: [], autoTilesKilledByOtherLayerUid: null,
            uiFilterTags: [], useAsyncRender: false,
            intGridValues: [], intGridValuesGroups: [], autoRuleGroups: [],
            autoSourceLayerDefUid: null,
            tilesetDefUid: UID.TILESET,
            tilePivotX: 0, tilePivotY: 0, biomeFieldUid: null,
        },
        {
            __type: "Tiles", identifier: "Foreground", type: "Tiles", uid: UID.LAYER_FG,
            doc: null, uiColor: null, gridSize: TILE,
            guideGridWid: 0, guideGridHei: 0,
            displayOpacity: 1, inactiveOpacity: 0.6, hideInList: false,
            hideFieldsWhenInactive: true, canSelectWhenInactive: true, renderInWorldView: true,
            pxOffsetX: 0, pxOffsetY: 0, parallaxFactorX: 0, parallaxFactorY: 0, parallaxScaling: true,
            requiredTags: [], excludedTags: [], autoTilesKilledByOtherLayerUid: null,
            uiFilterTags: [], useAsyncRender: false,
            intGridValues: [], intGridValuesGroups: [], autoRuleGroups: [],
            autoSourceLayerDefUid: null,
            tilesetDefUid: UID.TILESET,
            tilePivotX: 0, tilePivotY: 0, biomeFieldUid: null,
        },
        // Entities layer
        {
            __type: "Entities", identifier: "Hotspots", type: "Entities", uid: UID.LAYER_HOTSPOTS,
            doc: null, uiColor: null, gridSize: TILE,
            guideGridWid: 0, guideGridHei: 0,
            displayOpacity: 1, inactiveOpacity: 0.6, hideInList: false,
            hideFieldsWhenInactive: true, canSelectWhenInactive: true, renderInWorldView: true,
            pxOffsetX: 0, pxOffsetY: 0, parallaxFactorX: 0, parallaxFactorY: 0, parallaxScaling: true,
            requiredTags: [], excludedTags: [], autoTilesKilledByOtherLayerUid: null,
            uiFilterTags: [], useAsyncRender: false,
            intGridValues: [], intGridValuesGroups: [], autoRuleGroups: [],
            autoSourceLayerDefUid: null,
            tilesetDefUid: null,
            tilePivotX: 0, tilePivotY: 0, biomeFieldUid: null,
        },
        // IntGrid layer
        {
            __type: "IntGrid", identifier: "Collision", type: "IntGrid", uid: UID.LAYER_COLLIDE,
            doc: null, uiColor: null, gridSize: TILE,
            guideGridWid: 0, guideGridHei: 0,
            displayOpacity: 1, inactiveOpacity: 1, hideInList: false,
            hideFieldsWhenInactive: true, canSelectWhenInactive: true, renderInWorldView: true,
            pxOffsetX: 0, pxOffsetY: 0, parallaxFactorX: 0, parallaxFactorY: 0, parallaxScaling: true,
            requiredTags: [], excludedTags: [], autoTilesKilledByOtherLayerUid: null,
            uiFilterTags: [], useAsyncRender: false,
            intGridValues: [
                { value: 1, identifier: "Solid", color: "#000000", tile: null, groupUid: 0 },
            ],
            intGridValuesGroups: [], autoRuleGroups: [],
            autoSourceLayerDefUid: null,
            tilesetDefUid: null,
            tilePivotX: 0, tilePivotY: 0, biomeFieldUid: null,
        },
    ];

    const entityDefs = [
        {
            identifier: "Hotspot", uid: UID.ENTITY_HOTSPOT,
            tags: [], exportToToc: false, allowOutOfBounds: false, doc: null,
            width: TILE, height: TILE,
            resizableX: true, resizableY: true,
            minWidth: null, maxWidth: null, minHeight: null, maxHeight: null,
            keepAspectRatio: false,
            tileOpacity: 1, fillOpacity: 0.08, lineOpacity: 1, hollow: true,
            color: "#FF0000", renderMode: "Rectangle", showName: true,
            tilesetId: null, tileRenderMode: "FitInside", tileRect: null, uiTileRect: null,
            nineSliceBorders: [],
            maxCount: 0, limitScope: "PerLevel", limitBehavior: "MoveLastOne",
            pivotX: 0, pivotY: 0,
            fieldDefs: [
                {
                    identifier: "hotspot_id", doc: null,
                    __type: "String", uid: UID.FIELD_HS_ID, type: "F_String",
                    isArray: false, canBeNull: false,
                    arrayMinLength: null, arrayMaxLength: null,
                    editorDisplayMode: "ValueOnly", editorDisplayScale: 1,
                    editorDisplayPos: "Above", editorLinkStyle: "StraightArrow",
                    editorDisplayColor: null, editorAlwaysShow: false,
                    editorShowInWorld: true, editorCutLongValues: true,
                    editorTextSuffix: null, editorTextPrefix: null,
                    useForSmartColor: false, exportToToc: false, searchable: false,
                    min: null, max: null, regex: null,
                    acceptFileTypes: null, defaultOverride: null,
                    textLanguageMode: null,
                    symmetricalRef: false, autoChainRef: true,
                    allowOutOfLevelRef: true, allowedRefs: "OnlySame",
                    allowedRefsEntityUid: null, allowedRefTags: [], tilesetUid: null,
                },
                {
                    identifier: "tier", doc: null,
                    __type: "Int", uid: UID.FIELD_HS_TIER, type: "F_Int",
                    isArray: false, canBeNull: false,
                    arrayMinLength: null, arrayMaxLength: null,
                    editorDisplayMode: "ValueOnly", editorDisplayScale: 1,
                    editorDisplayPos: "Above", editorLinkStyle: "StraightArrow",
                    editorDisplayColor: null, editorAlwaysShow: false,
                    editorShowInWorld: true, editorCutLongValues: true,
                    editorTextSuffix: null, editorTextPrefix: null,
                    useForSmartColor: false, exportToToc: false, searchable: false,
                    min: 1, max: 3, regex: null,
                    acceptFileTypes: null,
                    defaultOverride: { id: "V_Int", params: [1] },
                    textLanguageMode: null,
                    symmetricalRef: false, autoChainRef: true,
                    allowOutOfLevelRef: true, allowedRefs: "OnlySame",
                    allowedRefsEntityUid: null, allowedRefTags: [], tilesetUid: null,
                },
                {
                    identifier: "label", doc: null,
                    __type: "String", uid: UID.FIELD_HS_LABEL, type: "F_String",
                    isArray: false, canBeNull: true,
                    arrayMinLength: null, arrayMaxLength: null,
                    editorDisplayMode: "ValueOnly", editorDisplayScale: 1,
                    editorDisplayPos: "Above", editorLinkStyle: "StraightArrow",
                    editorDisplayColor: null, editorAlwaysShow: false,
                    editorShowInWorld: true, editorCutLongValues: true,
                    editorTextSuffix: null, editorTextPrefix: null,
                    useForSmartColor: false, exportToToc: false, searchable: false,
                    min: null, max: null, regex: null,
                    acceptFileTypes: null, defaultOverride: null,
                    textLanguageMode: null,
                    symmetricalRef: false, autoChainRef: true,
                    allowOutOfLevelRef: true, allowedRefs: "OnlySame",
                    allowedRefsEntityUid: null, allowedRefTags: [], tilesetUid: null,
                },
                {
                    identifier: "tool_required", doc: null,
                    __type: "String", uid: UID.FIELD_HS_TOOL, type: "F_String",
                    isArray: false, canBeNull: true,
                    arrayMinLength: null, arrayMaxLength: null,
                    editorDisplayMode: "ValueOnly", editorDisplayScale: 1,
                    editorDisplayPos: "Above", editorLinkStyle: "StraightArrow",
                    editorDisplayColor: null, editorAlwaysShow: false,
                    editorShowInWorld: true, editorCutLongValues: true,
                    editorTextSuffix: null, editorTextPrefix: null,
                    useForSmartColor: false, exportToToc: false, searchable: false,
                    min: null, max: null, regex: null,
                    acceptFileTypes: null, defaultOverride: null,
                    textLanguageMode: null,
                    symmetricalRef: false, autoChainRef: true,
                    allowOutOfLevelRef: true, allowedRefs: "OnlySame",
                    allowedRefsEntityUid: null, allowedRefTags: [], tilesetUid: null,
                },
            ],
        },
        {
            identifier: "player_spawn", uid: UID.ENTITY_SPAWN,
            tags: [], exportToToc: false, allowOutOfBounds: false, doc: null,
            width: TILE, height: TILE,
            resizableX: false, resizableY: false,
            minWidth: null, maxWidth: null, minHeight: null, maxHeight: null,
            keepAspectRatio: false,
            tileOpacity: 1, fillOpacity: 1, lineOpacity: 1, hollow: false,
            color: "#00FF00", renderMode: "Cross", showName: true,
            tilesetId: null, tileRenderMode: "FitInside", tileRect: null, uiTileRect: null,
            nineSliceBorders: [],
            maxCount: 1, limitScope: "PerLevel", limitBehavior: "MoveLastOne",
            pivotX: 0, pivotY: 0, fieldDefs: [],
        },
    ];

    const enums = [
        {
            identifier: "TileTag", uid: UID.ENUM_TILE_TAG,
            values: [
                { id: "Solid",       tileRect: null, color: 0x000000 },
                { id: "Interactive", tileRect: null, color: 0x00FF00 },
            ],
            iconTilesetUid: UID.TILESET,
            externalRelPath: null,
            externalFileChecksum: null,
            tags: [],
        },
    ];

    const project = {
        __header__: {
            fileType: "LDtk Project JSON",
            app: "LDtk",
            doc: "https://ldtk.io/json",
            schema: "https://ldtk.io/files/JSON_SCHEMA.json",
            appAuthor: "Sebastien 'deepnight' Benard",
            appVersion: "1.5.3",
            url: "https://ldtk.io",
        },
        iid: "00000000-0000-0000-0000-000000000001",
        jsonVersion: "1.5.3",
        appBuildId: 473703,
        nextUid: 999,
        identifierStyle: "Capitalize",
        toc: [],
        worldLayout: "Free",
        worldGridWidth: PX_W,
        worldGridHeight: PX_H,
        defaultLevelWidth: PX_W,
        defaultLevelHeight: PX_H,
        defaultPivotX: 0,
        defaultPivotY: 0,
        defaultGridSize: TILE,
        defaultEntityWidth: TILE,
        defaultEntityHeight: TILE,
        bgColor: "#FFFFFF",
        defaultLevelBgColor: "#FFFFFF",
        minifyJson: false,
        externalLevels: false,
        exportTiled: false,
        simplifiedExport: false,
        imageExportMode: "None",
        exportLevelBg: true,
        pngFilePattern: null,
        backupOnSave: false,
        backupLimit: 10,
        backupRelPath: null,
        levelNamePattern: "%name",
        tutorialDesc: null,
        customCommands: [],
        flags: [],
        defs: {
            layers: layerDefs,
            entities: entityDefs,
            tilesets: [tilesetDef],
            enums,
            externalEnums: [],
            levelFields: [],
        },
        levels: [
            buildLevel({
                identifier: "Bedroom",
                iidString: bedroomIid,
                uid: UID.LEVEL_BEDROOM,
                worldX: 0, worldY: 0,
                payload: bedroom,
            }),
            buildLevel({
                identifier: "Playground",
                iidString: playgroundIid,
                uid: UID.LEVEL_PG,
                worldX: PX_W + 32, worldY: 0,
                payload: playground,
            }),
        ],
        worlds: [],
        dummyWorldIid: "00000000-0000-0000-0000-000000000002",
    };

    return project;
}

// ---------------------------------------------------------------------------
// emit
// ---------------------------------------------------------------------------
const project = build();
const outPath = path.join(__dirname, "..", "..", "source", "levels", "world.ldtk");
fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, JSON.stringify(project, null, "\t"));
console.log(`wrote ${outPath}`);

// quick stats
const lv1 = project.levels[0];
const lv2 = project.levels[1];
const tileCount = (lv) => lv.layerInstances.reduce((n, l) => n + l.gridTiles.length, 0);
const entCount = (lv) => lv.layerInstances.reduce((n, l) => n + l.entityInstances.length, 0);
console.log(`  ${lv1.identifier}:    ${tileCount(lv1)} tiles, ${entCount(lv1)} entities`);
console.log(`  ${lv2.identifier}: ${tileCount(lv2)} tiles, ${entCount(lv2)} entities`);
