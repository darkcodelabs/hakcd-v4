#!/usr/bin/env node
'use strict';
// tools/canon/generate_animations_manifest.js
//
// Phase 5 of canon-first migration. Parses source/sprites/*.lua addState
// calls + hand-authored animation specs and emits source/data/animations.lua.
//
// Manifest format (per revised plan Phase 5):
//   animations.<character>.<state_name> = {
//       frames        = {1, 2, 3, 4},          -- explicit indices
//       frameDuration = 30,                     -- ticks per frame
//       loop          = true,
//       fallback      = 'idle_south',           -- play-once → fallback
//       blocks_input  = false,                  -- true blocks d-pad
//   }
//
// Phase 9 sprite migration consumes this and loads addState dynamically.
// Phase 7 validator confirms frames[] indices are within asset.frame_count.

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '../..');
const OUT  = path.join(ROOT, 'source/data/animations.lua');

// ---------- Hand-curated specs (sprite-author intent) ----------
// Phase 9 will swap Newb.lua's inline addState calls for a loop over
// this table. Until then, this is the canonical record of WHAT the
// inline calls already declare — keep this in sync if Newb.lua changes.

const animations = {};
animations.newb = {
    idle_south: {
        frames:        [1, 2],
        frameDuration: 30,
        loop:          true,
        fallback:      null,
        blocks_input:  false,
        bible_anim_id: 'newb_idle_south'
    },
    walk_south: {
        frames:        [3, 4, 5, 6],
        frameDuration: 6,
        loop:          true,
        fallback:      'idle_south',
        blocks_input:  false,
        bible_anim_id: 'newb_walk_south'
    },
    idle_north: {
        // v0.1.11 staged frames {7, 12} via opts.frames; manifest declares
        // intended layout (not-yet-shipped breathing variant) so Phase 9
        // sprite loader can adopt it.
        frames:        [7, 12],
        frameDuration: 30,
        loop:          true,
        fallback:      null,
        blocks_input:  false,
        bible_anim_id: 'newb_idle_north'
    },
    walk_north: {
        frames:        [8, 9, 10, 11],
        frameDuration: 6,
        loop:          true,
        fallback:      'idle_north',
        blocks_input:  false,
        bible_anim_id: 'newb_walk_north'
    },
    idle_east: {
        frames:        [13, 18],
        frameDuration: 30,
        loop:          true,
        fallback:      null,
        blocks_input:  false,
        bible_anim_id: 'newb_idle_east'
    },
    walk_east: {
        frames:        [14, 15, 16, 17],
        frameDuration: 6,
        loop:          true,
        fallback:      'idle_east',
        blocks_input:  false,
        bible_anim_id: 'newb_walk_east'
    },
    idle_west: {
        frames:        [19, 24],
        frameDuration: 30,
        loop:          true,
        fallback:      null,
        blocks_input:  false,
        bible_anim_id: 'newb_idle_west'
    },
    walk_west: {
        frames:        [20, 21, 22, 23],
        frameDuration: 6,
        loop:          true,
        fallback:      'idle_west',
        blocks_input:  false,
        bible_anim_id: 'newb_walk_west'
    },
    interact: {
        frames:        [25],
        frameDuration: 30,
        loop:          false,
        fallback:      'idle_south',
        blocks_input:  true,
        bible_anim_id: 'newb_interact'
    },
    surprised: {
        frames:        [26],
        frameDuration: 30,
        loop:          false,
        fallback:      'idle_south',
        blocks_input:  false,
        bible_anim_id: 'newb_surprised'
    }
};

// System-tier animations (non-character UI effects)
animations.system = {
    terminal_typewriter: {
        frames:        null,   // text-driven, not imagetable-backed
        char_rate_ms:  28,
        loop:          false,
        bible_anim_id: 'terminal_typewriter',
        notes:         'ComputerScene typewriter cadence — 28ms per char'
    },
    lockpick_pin_set: {
        frames:        null,
        loop:          false,
        bible_anim_id: 'lockpick_pin_set',
        notes:         'flash + filled-pin render in pwnglove_lockpick state machine'
    },
    tyson_cabinet_attract: {
        frames:        null,
        loop:          true,
        bible_anim_id: 'tyson_cabinet_attract',
        notes:         'GFXP dot-5 dither overlay during TYSON MODE banner'
    },
    coin_vault_zoom: {
        frames:        null,
        loop:          false,
        bible_anim_id: 'coin_vault_zoom',
        notes:         'CoinVaultScene A-press transition grid -> closeup w/ rays'
    },
    crt_collapse: {
        frames:        null,
        loop:          false,
        bible_anim_id: 'crt_collapse',
        notes:         'TV-B-Gone die animation (future IR wall scene)'
    }
};

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

const out = `-- source/data/animations.lua
-- GENERATED by tools/canon/generate_animations_manifest.js — do not hand-edit.
-- Re-run when sprite animation specs change.
-- Phase 5 of canon-first migration plan.
--
-- Per-character animation state declarations:
--   frames        — explicit imagetable indices (or nil for non-imagetable system anims)
--   frameDuration — ticks per frame (AnimatedSprite tickStep equivalent)
--   loop          — bool
--   fallback      — state to switch to when play-once ends
--   blocks_input  — true halts d-pad reads while playing
--   bible_anim_id — link back to canon.animation_names id
--
-- Phase 9 sprite migration: Newb.lua loops over this table calling
-- addState dynamically instead of inline declarations.
-- Phase 7 validator: confirms frames[] within asset.frame_count.

local animations = ${luaValue(animations, 0)}

_G.animations_manifest = animations
return animations
`;

fs.writeFileSync(OUT, out);
console.log(`Wrote ${OUT}`);
const counts = {};
for (const character of Object.keys(animations)) {
    counts[character] = Object.keys(animations[character]).length;
}
console.log('  per-character states:', counts);
