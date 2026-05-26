#!/usr/bin/env node
'use strict';
// tools/canon/generate_canon.js
//
// Phase 2 of canon-first migration. Reads source/data/bible_parsed.json
// (Phase 1 output) + cross-references current LDtk/scene/sprite files
// for hotspot ids and emits source/data/canon.lua — the single
// source-of-truth for every id in the game.
//
// Re-run after parse_bible.js. Never hand-edit canon.lua.

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '../..');
const BIBLE = path.join(ROOT, 'source/data/bible_parsed.json');
const OUT   = path.join(ROOT, 'source/data/canon.lua');

const bible = JSON.parse(fs.readFileSync(BIBLE, 'utf8'));

// ---------- Characters ----------
const characters = {};
// Main, antagonist, mentor first
if (bible.main_character) {
    characters.newb = {
        id: 'newb',
        name: 'newb',
        role: 'protagonist',
        sprite_table: 'images/newb-table-32-32',
        portrait: 'images/portraits/newb',
        bible_section: 'PROTAGONIST'
    };
}
if (bible.antagonist) {
    characters.redhook = {
        id: 'redhook',
        name: 'RedHook',
        role: 'antagonist',
        sprite_table: null,
        portrait: null,
        bible_section: 'ANTAGONIST: REDHOOK'
    };
}
if (bible.mentor) {
    characters.mentor = {
        id: 'mentor',
        name: 'The Mentor / The Daemon',
        role: 'mentor',
        sprite_table: null,
        portrait: null,
        bible_section: 'THE MENTOR / THE DAEMON'
    };
}

// Supporting NPCs
for (const npc of (bible.supporting_characters || [])) {
    characters[npc.id] = {
        id: npc.id,
        name: npc.name,
        role: 'supporting',
        cast_number: npc.num,
        sprite_table: null,
        portrait: null
    };
}

// ---------- Rooms ----------
// HAKCD rooms = SC01..SC26 + the v4 invented technical rooms
//   (TitleScene / PlaygroundScene which are screens not story locations).
// Map each bible scene to a room id; flag v4 build-only screens separately.
const rooms = {};
for (const s of (bible.scenes || [])) {
    rooms[s.id] = {
        id: s.id,
        bible_name: s.name,
        act: s.act,
        is_story_room: true,
        ldtk_level: null   // populated by Phase 6 (rooms.lua) when LDtk levels exist
    };
}
// v4 invented screens — not story rooms, but referenced by build
rooms.title       = { id: 'title',       bible_name: 'Title Splash',         act: null, is_story_room: false, ldtk_level: null };
rooms.playground  = { id: 'playground',  bible_name: 'PWNGLOVE MODE (sandbox)', act: null, is_story_room: false, ldtk_level: 'Playground' };

// LDtk levels currently shipped (Bedroom maps to sc01)
rooms.sc01.ldtk_level = 'Bedroom';

// ---------- Scenes (build-level scenes, not bible-scenes) ----------
// Bible scenes are story locations. Build scenes are the actual NobleScene
// classes that exist in source/scenes/. They map onto rooms but the mapping
// is many-to-one (BedroomScene + ComputerScene + ModemScene + PhoneScene
// all bind to sc01).
const scenes = {
    TitleScene:    { id: 'TitleScene',    class: 'TitleScene',    room: 'title',       parent: null, kind: 'splash' },
    BedroomScene:  { id: 'BedroomScene',  class: 'BedroomScene',  room: 'sc01',        parent: null, kind: 'room' },
    ComputerScene: { id: 'ComputerScene', class: 'ComputerScene', room: 'sc01',        parent: 'BedroomScene', kind: 'modal' },
    ModemScene:    { id: 'ModemScene',    class: 'ModemScene',    room: 'sc01',        parent: 'BedroomScene', kind: 'modal' },
    PhoneScene:    { id: 'PhoneScene',    class: 'PhoneScene',    room: 'sc01',        parent: 'BedroomScene', kind: 'modal' },
    PlaygroundScene: { id: 'PlaygroundScene', class: 'PlaygroundScene', room: 'playground', parent: null, kind: 'room' },
    LockpickScene: { id: 'LockpickScene', class: 'LockpickScene', room: 'playground',  parent: 'PlaygroundScene', kind: 'minigame' },
    TysonScene:    { id: 'TysonScene',    class: 'TysonScene',    room: 'playground',  parent: 'PlaygroundScene', kind: 'minigame' },
    CoinVaultScene:{ id: 'CoinVaultScene',class: 'CoinVaultScene',room: 'playground',  parent: 'PlaygroundScene', kind: 'overlay' },
    SpriteTestScene:{ id: 'SpriteTestScene', class: 'SpriteTestScene', room: null,    parent: null, kind: 'dev_only' }
};

// ---------- Objects (interactables / hotspots) ----------
const objects = {
    computer: { id: 'computer', room: 'sc01', is_hotspot: true, launches: 'ComputerScene', label: 'USE COMPUTER' },
    modem:    { id: 'modem',    room: 'sc01', is_hotspot: true, launches: 'ModemScene',    label: 'USE MODEM' },
    phone:    { id: 'phone',    room: 'sc01', is_hotspot: true, launches: 'PhoneScene',    label: 'ANSWER PHONE' },
    bed:      { id: 'bed',      room: 'sc01', is_hotspot: true, launches: null,            label: 'SLEEP', sleeps: true, transitions_to: 'PlaygroundScene' },

    lockpick_station: { id: 'lockpick_station', room: 'playground', is_hotspot: true, launches: 'LockpickScene', label: 'LOCKPICK' },
    tyson_cabinet:    { id: 'tyson_cabinet',    room: 'playground', is_hotspot: true, launches: 'TysonScene',    label: 'TYSON' },
    coin_vault:       { id: 'coin_vault',       room: 'playground', is_hotspot: true, launches: 'CoinVaultScene', label: 'COIN VAULT' },
    rfid_pedestal:    { id: 'rfid_pedestal',    room: 'playground', is_hotspot: true, launches: null, label: 'RFID', placeholder: true },
    payphone:         { id: 'payphone',         room: 'playground', is_hotspot: true, launches: null, label: 'PAYPHONE', placeholder: true },
    ir_wall:          { id: 'ir_wall',          room: 'playground', is_hotspot: true, launches: null, label: 'IR WALL', placeholder: true },
    gravity_arena:    { id: 'gravity_arena',    room: 'playground', is_hotspot: true, launches: null, label: 'GRAVITY', placeholder: true },
    subghz_tuner:     { id: 'subghz_tuner',     room: 'playground', is_hotspot: true, launches: null, label: 'SUBGHZ', placeholder: true },
    portal_pedestal:  { id: 'portal_pedestal',  room: 'playground', is_hotspot: true, launches: null, label: 'PORTAL', placeholder: true }
};

// ---------- Dialogue ids ----------
const dialogue_ids = {
    mom_intro:           { id: 'mom_intro',           speaker: 'mom',     triggered_by_object: 'phone', scene: 'PhoneScene', lines_count: 5 },
    bbs_boot_sequence:   { id: 'bbs_boot_sequence',   speaker: 'system',  triggered_by_object: 'computer', scene: 'ComputerScene', lines_count: 3 },
    modem_war_dialer:    { id: 'modem_war_dialer',    speaker: 'system',  triggered_by_object: 'modem', scene: 'ModemScene', lines_count: 14 },
    coin_zero_welcome:   { id: 'coin_zero_welcome',   speaker: 'newb',    triggered_by_object: 'coin_vault', scene: 'CoinVaultScene' },
    tyson_already:       { id: 'tyson_already',       speaker: 'system',  triggered_by_object: 'tyson_cabinet', scene: 'TysonScene', when: 'tyson_unlock==true' }
};

// ---------- State flags ----------
const state_flags = {
    tyson_unlock:           { id: 'tyson_unlock',           persisted: true, default: false, set_by: ['TysonScene'], read_by: ['TysonScene', 'PlaygroundScene', 'BedroomScene'] },
    pwnglove_mode_complete: { id: 'pwnglove_mode_complete', persisted: true, default: false, set_by: ['PlaygroundScene'], read_by: ['PlaygroundScene'] },
    current_act:            { id: 'current_act',            persisted: true, default: 1,     set_by: [], read_by: ['BedroomScene', 'PlaygroundScene'] }
};

// Coin status flags — one per coin id 0..23
for (let i = 0; i < 24; i++) {
    state_flags[`coin_${i}_status`] = {
        id: `coin_${i}_status`,
        persisted: true,
        default: i === 0 ? 'minted' : (i <= 2 ? 'available' : 'locked'),
        set_by: ['CoinVaultScene'],
        read_by: ['CoinVaultScene']
    };
}

// ---------- Animation names ----------
const animation_names = {};
for (const a of (bible.required_animations || [])) {
    animation_names[a.id] = {
        id: a.id,
        character: a.character,
        sprite_table: a.character === 'newb' ? 'images/newb-table-32-32' : null
    };
}

// ---------- Asset paths ----------
const asset_paths = {
    title:          'images/title',
    pwnglove_icon:  'images/pwnglove_icon',
    newb_table:     'images/newb-table-32-32',
    newb_portrait:  'images/portraits/newb',
    lockpick_body:  'images/ui/lockpick_body',
    playground_bg:  'images/scenes/pwnglove_playground',
    tileset_hakcd:  'images/tilesets/hakcd-table-24-24'
};
for (let i = 0; i < 4; i++) {
    asset_paths[`coin_${i}`]       = `images/coins/coin_${i}`;
    asset_paths[`coin_${i}_large`] = `images/coins/coin_${i}_large`;
}
asset_paths.coin_locked = 'images/coins/coin_locked';

// ---------- SFX + music ids (mirror sounds/manifest.lua) ----------
const sfx_ids = {};
for (const n of [
    'lockpick_pin_click_1', 'lockpick_pin_click_2', 'lockpick_pin_click_3', 'lockpick_pin_click_4',
    'lockpick_pin_set', 'lockpick_snap', 'lockpick_tension_warn', 'lockpick_open',
    'tyson_digit_select', 'tyson_digit_commit', 'tyson_winner',
    'coin_navigate_tick', 'coin_zoom_whoosh', 'coin_mint',
    'pwnglove_boot', 'step_1', 'step_2'
]) {
    sfx_ids[n] = { id: n, path: `sounds/sfx/${n}` };
}
const music_ids = {
    title_loop:      { id: 'title_loop',      path: 'sounds/music/title_loop' },
    bedroom_loop:    { id: 'bedroom_loop',    path: 'sounds/music/bedroom_loop' },
    playground_loop: { id: 'playground_loop', path: 'sounds/music/playground_loop' },
    tyson_loop:      { id: 'tyson_loop',      path: 'sounds/music/tyson_loop' },
    coinvault_loop:  { id: 'coinvault_loop',  path: 'sounds/music/coinvault_loop' }
};

// ---------- Emit canon.lua ----------

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

const out = `-- source/data/canon.lua
-- GENERATED by tools/canon/generate_canon.js — do not hand-edit.
-- Re-run after tools/bible/parse_bible.js if the bible changes.
-- Phase 2 of canon-first migration plan.
--
-- Single source-of-truth for every id in the game. Scenes / sprites /
-- progression / asset loaders MUST read ids through this table, never
-- as bare strings.

local canon = {}

canon.game = {
    title = ${luaValue(bible.game_title)},
    genre = ${luaValue(bible.genre)},
    tone  = ${luaValue(bible.tone)},
    timeline = ${luaValue(bible.timeline)},
    core_premise = ${luaValue(bible.core_premise)}
}

canon.characters = ${luaValue(characters, 0)}

canon.rooms = ${luaValue(rooms, 0)}

canon.scenes = ${luaValue(scenes, 0)}

canon.objects = ${luaValue(objects, 0)}

canon.dialogue_ids = ${luaValue(dialogue_ids, 0)}

canon.state_flags = ${luaValue(state_flags, 0)}

canon.animation_names = ${luaValue(animation_names, 0)}

canon.asset_paths = ${luaValue(asset_paths, 0)}

canon.sfx_ids = ${luaValue(sfx_ids, 0)}

canon.music_ids = ${luaValue(music_ids, 0)}

-- Convenience: id-presence assertion. Wraps a canon lookup with a
-- loud error so typos fail at load time, not silently at runtime.
function canon.assert_id(category_name, id)
    local cat = canon[category_name]
    assert(cat, "canon: unknown category '" .. tostring(category_name) .. "'")
    assert(cat[id], "canon: unknown id '" .. tostring(id) .. "' in '" .. category_name .. "'")
    return cat[id]
end

_G.canon = canon
return canon
`;

fs.writeFileSync(OUT, out);
console.log(`Wrote ${OUT}`);
console.log(`  characters=${Object.keys(characters).length}, rooms=${Object.keys(rooms).length}, scenes=${Object.keys(scenes).length}, objects=${Object.keys(objects).length}, state_flags=${Object.keys(state_flags).length}, animations=${Object.keys(animation_names).length}, assets=${Object.keys(asset_paths).length}, sfx=${Object.keys(sfx_ids).length}, music=${Object.keys(music_ids).length}`);
