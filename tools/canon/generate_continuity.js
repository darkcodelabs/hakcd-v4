#!/usr/bin/env node
'use strict';
// tools/canon/generate_continuity.js
//
// Phase 3 of canon-first migration. Reads canon.lua's tables (via JSON
// passthrough from bible_parsed.json + v4 build map) and emits
// source/data/continuity.lua — the declarative scene order, flag rules,
// transitions, dialogue unlock rules, inventory/puzzle requirements.
//
// Re-run after generate_canon.js. Never hand-edit continuity.lua.
// Phase 7 validator reads this + canon to fail on graph drift.

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '../..');
const BIBLE = path.join(ROOT, 'source/data/bible_parsed.json');
const OUT   = path.join(ROOT, 'source/data/continuity.lua');

const bible = JSON.parse(fs.readFileSync(BIBLE, 'utf8'));

// ---------- Scene order (build-level, traversal-order) ----------
// Bible scenes (sc01..sc26) define story order. Build scenes traverse:
// title -> bedroom -> (modals) -> playground -> (minigames) -> bedroom -> ...
const scene_order = [
    'TitleScene',
    'BedroomScene',
    'ComputerScene',
    'ModemScene',
    'PhoneScene',
    'PlaygroundScene',
    'LockpickScene',
    'TysonScene',
    'CoinVaultScene'
];

// ---------- Per-scene continuity entries ----------
const scenes = [
    {
        id: 'TitleScene',
        room: 'title',
        required_flags: [],
        sets_flags: [],
        characters: ['newb'],
        objects: [],
        transitions_to: ['BedroomScene']
    },
    {
        id: 'BedroomScene',
        room: 'sc01',
        required_flags: [],
        sets_flags: [],
        characters: ['newb', 'mom'],
        objects: ['computer', 'modem', 'phone', 'bed'],
        transitions_to: ['ComputerScene', 'ModemScene', 'PhoneScene', 'PlaygroundScene']
    },
    {
        id: 'ComputerScene',
        room: 'sc01',
        parent_scene: 'BedroomScene',
        required_flags: [],
        sets_flags: [],
        characters: ['newb', 'mentor'],
        objects: ['computer'],
        transitions_to: ['BedroomScene'],
        dialogue: ['bbs_boot_sequence']
    },
    {
        id: 'ModemScene',
        room: 'sc01',
        parent_scene: 'BedroomScene',
        required_flags: [],
        sets_flags: [],
        characters: ['newb'],
        objects: ['modem'],
        transitions_to: ['BedroomScene'],
        dialogue: ['modem_war_dialer']
    },
    {
        id: 'PhoneScene',
        room: 'sc01',
        parent_scene: 'BedroomScene',
        required_flags: [],
        sets_flags: [],
        characters: ['newb', 'mom'],
        objects: ['phone'],
        transitions_to: ['BedroomScene'],
        dialogue: ['mom_intro']
    },
    {
        id: 'PlaygroundScene',
        room: 'playground',
        required_flags: [],
        sets_flags: ['pwnglove_mode_complete'],
        characters: ['newb'],
        objects: [
            'lockpick_station', 'tyson_cabinet', 'coin_vault',
            'rfid_pedestal', 'payphone', 'ir_wall',
            'gravity_arena', 'subghz_tuner', 'portal_pedestal'
        ],
        transitions_to: ['LockpickScene', 'TysonScene', 'CoinVaultScene']
    },
    {
        id: 'LockpickScene',
        room: 'playground',
        parent_scene: 'PlaygroundScene',
        required_flags: [],
        sets_flags: [],
        characters: ['newb'],
        objects: ['lockpick_station'],
        transitions_to: ['PlaygroundScene']
    },
    {
        id: 'TysonScene',
        room: 'playground',
        parent_scene: 'PlaygroundScene',
        required_flags: [],
        sets_flags: ['tyson_unlock'],
        characters: ['newb'],
        objects: ['tyson_cabinet'],
        transitions_to: ['PlaygroundScene'],
        dialogue: ['tyson_already']
    },
    {
        id: 'CoinVaultScene',
        room: 'playground',
        parent_scene: 'PlaygroundScene',
        required_flags: [],
        sets_flags: [],
        characters: ['newb'],
        objects: ['coin_vault'],
        transitions_to: ['PlaygroundScene'],
        dialogue: ['coin_zero_welcome']
    }
];

// ---------- Flag rules ----------
const flag_rules = {
    tyson_persistence: {
        flag: 'tyson_unlock',
        rule: 'Once set true via TysonScene win, persists across sessions via Noble.GameData. Subsequent TysonScene entries enter already_granted branch.'
    },
    coin_mint_progression: {
        flag_prefix: 'coin_*_status',
        rule: 'Each coin transitions locked -> available -> minted. Available unlock fires when phrase discovered (placeholder until phrase puzzles ship). Coin 0 minted by default.'
    },
    pwnglove_mode_completion: {
        flag: 'pwnglove_mode_complete',
        rule: 'Set true when all 9 playground stations have been A-pressed at least once. Tracked transiently by PlaygroundScene; persisted on first all-9 visit.'
    },
    act_progression: {
        flag: 'current_act',
        rule: '1..4 (+ Coda). Increments on per-act final scene completion. Currently no scenes advance act — placeholder for Phase 12+ when bible scenes wire in.'
    }
};

// ---------- Dialogue unlock rules ----------
const dialogue_unlock_rules = {
    mom_intro:           { unlocked_by: 'enter_phone_hotspot',          repeatable: true },
    bbs_boot_sequence:   { unlocked_by: 'enter_computer_hotspot',       repeatable: true },
    modem_war_dialer:    { unlocked_by: 'enter_modem_hotspot',          repeatable: true },
    coin_zero_welcome:   { unlocked_by: 'enter_coin_vault_for_first',   repeatable: false },
    tyson_already:       { unlocked_by: 'tyson_unlock_flag_true',       repeatable: true,
                           requires_flag: { name: 'tyson_unlock', value: true } }
};

// ---------- Inventory requirements (bible skill_gates → per-scene) ----------
// Bible skill_gates table is per-beat, not per-scene. Map what we can.
const inventory_requirements = {};
for (const g of (bible.skill_gates || [])) {
    inventory_requirements[g.beat] = {
        beat: g.beat,
        required_tool: g.required_tool,
        optional_tools: g.optional_tools
    };
}

// ---------- Puzzle progression ----------
const puzzle_progression = {
    lockpick: {
        scene: 'LockpickScene',
        bible_beat: 'Act 3 b3: Beige box tap on Bell pedestal',
        unlock_state: 'available_at_act3',
        gating_tool: 'Lockpick + Beige Box',
        currently_implemented: true,
        current_invocation_room: 'playground'
    },
    tyson_code: {
        scene: 'TysonScene',
        bible_beat: 'easter egg — pre-canonical',
        unlock_state: 'always_available_when_pwnglove_equipped',
        gating_tool: 'PWNGLOVE',
        currently_implemented: true,
        current_invocation_room: 'playground'
    },
    coin_vault: {
        scene: 'CoinVaultScene',
        bible_beat: 'collection — per-coin phrase discovery',
        unlock_state: 'always_browsable_in_playground',
        gating_tool: 'PWNGLOVE',
        currently_implemented: true,
        current_invocation_room: 'playground'
    }
};

// ---------- Room availability ----------
const room_availability = {
    title:       { available_when: 'always' },
    sc01:        { available_when: 'always (recurring hub)' },
    playground:  { available_when: 'always (system menu accessible)' }
};
for (const s of (bible.scenes || [])) {
    if (s.id === 'sc01') continue;   // already entered
    room_availability[s.id] = {
        available_when: `bible scene ${s.id.toUpperCase()} (${s.act}) — not yet implemented in v4 build`
    };
}

// ---------- Bible-driven scene order (story canon) ----------
const bible_scene_order = (bible.scenes || []).map(s => s.id);

// ---------- Emit Lua ----------

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

const out = `-- source/data/continuity.lua
-- GENERATED by tools/canon/generate_continuity.js — do not hand-edit.
-- Re-run after generate_canon.js when story progression changes.
-- Phase 3 of canon-first migration plan.
--
-- Declarative scene order + flag rules + dialogue unlock rules +
-- inventory requirements + puzzle progression + room availability.
-- Phase 7 validator (validate_continuity.sh) reads this + canon.lua
-- to fail build on graph drift.

local continuity = {}

-- Build-scene traversal order (TitleScene -> Bedroom -> modals -> Playground -> minigames)
continuity.scene_order = ${luaValue(scene_order, 0)}

-- Bible story-scene order (SC01..SC26 + coda)
continuity.bible_scene_order = ${luaValue(bible_scene_order, 0)}

-- Per-scene continuity entries — required/sets flags, characters, objects, transitions
continuity.scenes = ${luaValue(scenes, 0)}

-- Named flag rules (cross-scene state contracts)
continuity.flag_rules = ${luaValue(flag_rules, 0)}

-- Dialogue unlock rules — when each dialogue id becomes playable
continuity.dialogue_unlock_rules = ${luaValue(dialogue_unlock_rules, 0)}

-- Per-beat tool/inventory requirements (from bible SKILL GATE MAP)
continuity.inventory_requirements = ${luaValue(inventory_requirements, 0)}

-- Per-puzzle progression metadata
continuity.puzzle_progression = ${luaValue(puzzle_progression, 0)}

-- Room availability — when each room is reachable
continuity.room_availability = ${luaValue(room_availability, 0)}

_G.continuity = continuity
return continuity
`;

fs.writeFileSync(OUT, out);
console.log(`Wrote ${OUT}`);
console.log(`  scene_order=${scene_order.length}, bible_scene_order=${bible_scene_order.length}, scenes=${scenes.length}, flag_rules=${Object.keys(flag_rules).length}, dialogue_rules=${Object.keys(dialogue_unlock_rules).length}, inventory_reqs=${Object.keys(inventory_requirements).length}, puzzles=${Object.keys(puzzle_progression).length}, rooms_listed=${Object.keys(room_availability).length}`);
