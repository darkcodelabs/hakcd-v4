#!/usr/bin/env node
'use strict';
// tools/canon/generate_rooms_manifest.js
//
// Phase 6 of canon-first migration. Emits source/data/rooms.lua —
// per-room declarative manifest: walkable bounds, exits, spawn points,
// interactable objects, NPCs, camera behavior, ambient anim refs,
// background asset id.
//
// Inputs (read-only):
//   - source/data/bible_parsed.json         (story metadata)
//   - source/levels/world.ldtk              (LDtk levels for walkable bounds + entities)
//   - source/data/canon.lua tables          (rooms / objects / characters — embedded
//                                            for cross-reference here as a literal
//                                            mirror; rooms.lua only needs the ids)
//
// Output:
//   - source/data/rooms.lua
//
// Re-run after generate_canon.js when room shapes / hotspot positions /
// LDtk levels change. Phase 7 validator confirms every rooms.lua id is
// present in canon.rooms and every exit.to_scene is in canon.scenes.
//
// Hard rules:
//   * Walkable bounds default to the LDtk level pxWid x pxHei when an LDtk
//     level exists. Non-LDtk rooms get a Playdate-screen fallback.
//   * spawn_points are extracted from LDtk player_spawn entities. Rooms
//     without an LDtk level get a single 'default' spawn at screen center.
//   * exits are extracted from LDtk Hotspot entities whose hotspot_id
//     matches a canon.objects entry with `launches` or `transitions_to`.
//   * interactable_objects = canon.objects ids whose `room` matches.
//   * npcs = canon characters appearing in this room (best-effort heuristic:
//     newb always present in walkable rooms; mom present in sc01; mentor
//     present where a `mentor` dialogue speaker fires).
//   * camera_behavior = 'static' for everything (HAKCD is a single-screen game).
//   * Bible-only scenes (sc02..sc26 except sc01) get not_yet_implemented=true,
//     ldtk_level=nil, walkable_bounds = nil so Phase 7 validator warns-but-
//     does-not-fail.

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '../..');
const BIBLE  = path.join(ROOT, 'source/data/bible_parsed.json');
const LDTK   = path.join(ROOT, 'source/levels/world.ldtk');
const OUT    = path.join(ROOT, 'source/data/rooms.lua');

const bible = JSON.parse(fs.readFileSync(BIBLE, 'utf8'));
const ldtk  = JSON.parse(fs.readFileSync(LDTK,  'utf8'));

// ---------- Mirror of canon ids we need to cross-reference ----------
// Kept as a literal here so this generator stays decoupled from running
// Lua. Must stay in sync with canon.lua tables. If canon.objects or
// canon.rooms gain new entries, mirror them here.

// room id → bible_name (only ids that exist in the current build; bible
// scenes sc02..sc26 are walked from bible.scenes directly).
const BUILD_ROOMS = {
    title:      { bible_name: 'Title Splash',           is_story_room: false, ldtk_level: null,         walkable: false },
    sc01:       { bible_name: 'Bedroom (recurring hub)', is_story_room: true,  ldtk_level: 'Bedroom',    walkable: true  },
    playground: { bible_name: 'PWNGLOVE MODE (sandbox)', is_story_room: false, ldtk_level: 'Playground', walkable: true  }
};

// Object id → { room, launches (scene), transitions_to (scene), label }.
// Mirror of canon.objects — kept literal to avoid running Lua.
const CANON_OBJECTS = {
    computer:         { room: 'sc01',       launches: 'ComputerScene', transitions_to: null,              label: 'USE COMPUTER' },
    modem:            { room: 'sc01',       launches: 'ModemScene',    transitions_to: null,              label: 'USE MODEM' },
    phone:            { room: 'sc01',       launches: 'PhoneScene',    transitions_to: null,              label: 'ANSWER PHONE' },
    bed:              { room: 'sc01',       launches: null,            transitions_to: 'PlaygroundScene', label: 'SLEEP' },
    lockpick_station: { room: 'playground', launches: 'LockpickScene', transitions_to: null,              label: 'LOCKPICK' },
    tyson_cabinet:    { room: 'playground', launches: 'TysonScene',    transitions_to: null,              label: 'TYSON' },
    coin_vault:       { room: 'playground', launches: 'CoinVaultScene',transitions_to: null,              label: 'COIN VAULT' },
    rfid_pedestal:    { room: 'playground', launches: null,            transitions_to: null,              label: 'RFID' },
    payphone:         { room: 'playground', launches: null,            transitions_to: null,              label: 'PAYPHONE' },
    ir_wall:          { room: 'playground', launches: null,            transitions_to: null,              label: 'IR WALL' },
    gravity_arena:    { room: 'playground', launches: null,            transitions_to: null,              label: 'GRAVITY' },
    subghz_tuner:     { room: 'playground', launches: null,            transitions_to: null,              label: 'SUBGHZ' },
    portal_pedestal:  { room: 'playground', launches: null,            transitions_to: null,              label: 'PORTAL' }
};

// Per-room NPC list (canon.characters ids). Heuristic — bible doesn't
// formally map characters to v4 rooms yet, but the shipped scenes/dialogue
// give us this concrete mapping.
const ROOM_NPCS = {
    title:      [],
    sc01:       ['mom'],          // mom is offscreen voice on PhoneScene; still 'present' in room
    playground: []                // newb-only sandbox
};

// Background asset id (from canon.asset_paths) for non-LDtk-tiled rooms.
// LDtk-tiled rooms render through the LDtk tileset, so background is nil.
const ROOM_BACKGROUND = {
    title:      'title',
    sc01:       null,             // LDtk-tiled
    playground: null              // LDtk-tiled (asset 'playground_bg' is the modal sandbox bg, not the walkable one)
};

// Per-room ambient animation object refs (canon.animation_names ids that
// loop in the room independent of player interaction). None shipped yet —
// reserved for Phase 10 polish.
const ROOM_AMBIENT_ANIMS = {
    title:      [],
    sc01:       [],
    playground: []
};

// ---------- LDtk helpers ----------

function ldtkLevel(name) {
    return (ldtk.levels || []).find(l => l.identifier === name);
}

function ldtkEntities(levelName, layerIdent) {
    const lvl = ldtkLevel(levelName);
    if (!lvl) return [];
    const layer = (lvl.layerInstances || []).find(li => li.__identifier === layerIdent);
    if (!layer) return [];
    return layer.entityInstances || [];
}

function entityFields(ei) {
    const out = {};
    for (const f of (ei.fieldInstances || [])) {
        out[f.__identifier] = f.__value;
    }
    return out;
}

// ---------- Build per-room entries ----------

function buildRoom(roomId, meta) {
    const lvl   = meta.ldtk_level ? ldtkLevel(meta.ldtk_level) : null;
    const entry = {
        id:                          roomId,
        bible_name:                  meta.bible_name,
        ldtk_level:                  meta.ldtk_level || null,
        is_story_room:               meta.is_story_room,
        not_yet_implemented:         false,
        walkable_bounds:             null,
        exits:                       [],
        spawn_points:                [],
        interactable_objects:        [],
        npcs:                        ROOM_NPCS[roomId] || [],
        camera_behavior:             'static',
        ambient_animation_objects:   ROOM_AMBIENT_ANIMS[roomId] || [],
        background:                  ROOM_BACKGROUND[roomId] || null
    };

    // Walkable bounds — LDtk level pxWid/pxHei (origin 0,0) if present.
    // Non-walkable splash rooms (title) get null bounds.
    if (meta.walkable && lvl) {
        entry.walkable_bounds = { x: 0, y: 0, w: lvl.pxWid, h: lvl.pxHei };
    } else if (!meta.walkable) {
        entry.walkable_bounds = null;
    } else {
        // walkable but no LDtk level — Playdate-screen fallback
        entry.walkable_bounds = { x: 0, y: 0, w: 400, h: 240 };
    }

    // Spawn points — every LDtk player_spawn entity becomes a named spawn.
    // First one is 'default'; subsequent ones use their LDtk identifier suffix
    // (or 'spawn_N' if unnamed).
    if (lvl) {
        const spawnEnts = [];
        for (const li of (lvl.layerInstances || [])) {
            for (const ei of (li.entityInstances || [])) {
                if (ei.__identifier === 'player_spawn') spawnEnts.push(ei);
            }
        }
        spawnEnts.forEach((ei, i) => {
            const fields = entityFields(ei);
            const id = fields.spawn_id
                    || (i === 0 ? 'default' : ('spawn_' + (i + 1)));
            entry.spawn_points.push({ id: id, x: ei.px[0], y: ei.px[1] });
        });
    }
    if (entry.spawn_points.length === 0 && meta.walkable) {
        // walkable room w/ no LDtk spawn — center of screen fallback
        entry.spawn_points.push({ id: 'default', x: 200, y: 168 });
    }

    // Exits — LDtk Hotspot entities whose hotspot_id maps to a canon.object
    // with a `launches` scene OR a `transitions_to` scene.
    if (lvl) {
        for (const li of (lvl.layerInstances || [])) {
            for (const ei of (li.entityInstances || [])) {
                if (ei.__identifier !== 'Hotspot') continue;
                const fields = entityFields(ei);
                const objId  = fields.hotspot_id;
                const obj    = CANON_OBJECTS[objId];
                if (!obj) continue;
                const toScene = obj.launches || obj.transitions_to;
                if (!toScene) continue;
                entry.exits.push({
                    from_object_id: objId,
                    to_scene:       toScene,
                    to_spawn:       'default'
                });
            }
        }
    }

    // Interactable objects — canon.objects entries pinned to this room.
    for (const [oid, o] of Object.entries(CANON_OBJECTS)) {
        if (o.room === roomId) entry.interactable_objects.push(oid);
    }

    return entry;
}

// ---------- Bible-only (not-yet-implemented) rooms ----------

function bibleOnlyRoom(s) {
    return {
        id:                        s.id,
        bible_name:                s.name || s.bible_name || s.title || s.id,
        ldtk_level:                null,
        is_story_room:             true,
        not_yet_implemented:       true,
        walkable_bounds:           null,
        exits:                     [],
        spawn_points:              [],
        interactable_objects:      [],
        npcs:                      [],
        camera_behavior:           'static',
        ambient_animation_objects: [],
        background:                null,
        act:                       s.act || null
    };
}

// ---------- Assemble rooms table ----------

const rooms = {};

// Build-shipped rooms
for (const [rid, meta] of Object.entries(BUILD_ROOMS)) {
    rooms[rid] = buildRoom(rid, meta);
}

// Bible-only story scenes (sc02..sc26) — declare them with the warn-not-block
// metadata Phase 7 validator looks for.
for (const s of (bible.scenes || [])) {
    if (s.id === 'sc01') continue;   // sc01 is the implemented bedroom
    if (rooms[s.id])     continue;   // already shipped
    rooms[s.id] = bibleOnlyRoom(s);
}

// ---------- Lua emit ----------

function luaEscape(s) {
    return String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n');
}
function luaValue(v, indent) {
    indent = indent || 0;
    const pad = '    '.repeat(indent);
    const padIn = '    '.repeat(indent + 1);
    if (v === null || v === undefined) return 'nil';
    if (typeof v === 'boolean') return v ? 'true' : 'false';
    if (typeof v === 'number') return String(v);
    if (typeof v === 'string') return `"${luaEscape(v)}"`;
    if (Array.isArray(v)) {
        if (v.length === 0) return '{}';
        const parts = v.map(x => padIn + luaValue(x, indent + 1));
        return '{\n' + parts.join(',\n') + '\n' + pad + '}';
    }
    if (typeof v === 'object') {
        const keys = Object.keys(v);
        if (keys.length === 0) return '{}';
        const parts = keys.map(k => {
            const safeKey = /^[A-Za-z_][A-Za-z0-9_]*$/.test(k) ? k : `["${luaEscape(k)}"]`;
            return padIn + safeKey + ' = ' + luaValue(v[k], indent + 1);
        });
        return '{\n' + parts.join(',\n') + '\n' + pad + '}';
    }
    return 'nil';
}

const out = `-- source/data/rooms.lua
-- GENERATED by tools/canon/generate_rooms_manifest.js — do not hand-edit.
-- Re-run after generate_canon.js when room shapes / hotspot positions /
-- LDtk levels change.
-- Phase 6 of canon-first migration plan.
--
-- Per-room declarative manifest:
--   id                          — matches canon.rooms[id]
--   bible_name                  — human-readable label from the bible
--   ldtk_level                  — LDtk level identifier (or nil if non-LDtk)
--   is_story_room               — bible canon scene vs sandbox/title
--   not_yet_implemented         — true for bible scenes without v4 build
--   walkable_bounds             — { x, y, w, h } in scene pixel coords (or nil)
--   exits                       — [{ from_object_id, to_scene, to_spawn }]
--   spawn_points                — [{ id, x, y }]
--   interactable_objects        — [canon.objects ids in this room]
--   npcs                        — [canon.characters ids present in room]
--   camera_behavior             — 'static' | 'follow' | 'scroll' (HAKCD: static)
--   ambient_animation_objects   — [canon.animation_names ids that loop]
--   background                  — canon.asset_paths id (or nil if LDtk-tiled)
--
-- Phase 7 validator (validate_rooms.sh) cross-checks every id against
-- canon.lua and warns on not_yet_implemented but does not block.

local rooms = ${luaValue(rooms, 0)}

_G.rooms_manifest = rooms
return rooms
`;

fs.writeFileSync(OUT, out);

const shipped = Object.values(rooms).filter(r => !r.not_yet_implemented).length;
const stubbed = Object.values(rooms).filter(r =>  r.not_yet_implemented).length;
const withLdtk = Object.values(rooms).filter(r => r.ldtk_level).length;
console.log(`Wrote ${OUT}`);
console.log(`  rooms total: ${Object.keys(rooms).length}`);
console.log(`  shipped: ${shipped} (${withLdtk} with ldtk_level), bible-stub: ${stubbed}`);
