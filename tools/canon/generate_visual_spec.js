#!/usr/bin/env node
'use strict';
// tools/canon/generate_visual_spec.js
//
// Phase V2 of visual recovery. Walks every shippable visual + audio asset
// in source/ and emits source/data/visual_spec.lua — the visual contract
// the Phase V3 validator will enforce. Each entry declares:
//
//   art_status                 — final | placeholder | generated | wip | debug
//   human_reviewed             — bool
//   reviewer / reviewed_at     — sign-off metadata (style_guide.md §12)
//   target_dimensions          — what style_guide says it SHOULD be
//   sheet_dimensions           — what it actually IS on disk
//   readability_min_pct_screen — vertical-occupancy floor (0.0-1.0)
//   meets_readability_min      — computed: sheet h / 240 >= required minimum
//   reference_image            — path under docs/reference/ (or canonical pin)
//   target_replacement_version — for placeholders, when V4-V8 lands the fix
//   notes                      — audit verdict + reasoning
//
// DO NOT infer art_status from heuristics. The STATUS_TABLE below is the
// explicit, audited classification (VISUAL_PIPELINE_FAILURE_AUDIT.md §3).
// Future versions may externalise this to visual_spec_status.json; for now
// it lives here so the reproducer is single-file.
//
// Reproducibility: keys are sorted alphabetically on emit so running this
// twice with no asset changes produces byte-identical output.

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ROOT = path.resolve(__dirname, '../..');
const OUT  = path.join(ROOT, 'source/data/visual_spec.lua');

// ---------- Walk helper ----------
function walk(dir, results) {
    results = results || [];
    if (!fs.existsSync(dir)) return results;
    const entries = fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name));
    for (const ent of entries) {
        if (ent.name.startsWith('.')) continue;
        const p = path.join(dir, ent.name);
        if (ent.isDirectory()) walk(p, results);
        else results.push(p);
    }
    return results;
}

function dim(filePath) {
    try {
        const out = execSync(`file "${filePath}"`, { encoding: 'utf8' });
        const m = out.match(/(\d+)\s*x\s*(\d+)/);
        if (m) return { w: parseInt(m[1], 10), h: parseInt(m[2], 10) };
    } catch (e) {}
    return { w: null, h: null };
}

// ---------- Explicit per-asset status table (audit §3 verdict) ----------
// Keyed by visual_spec id. Anything not listed defaults to:
//   art_status='placeholder', human_reviewed=false. Generators (sfx, music)
//   are detected by type below and overridden to 'generated' if absent here.
const STATUS_TABLE = {
    // -------- KEEP: canonical pins from the real 23-codes/23Coins repo --------
    title: {
        art_status: 'final', human_reviewed: true,
        reviewer: 'cory_k', reviewed_at: '2026-05-23',
        reference_image: 'docs/hakcd_title.png',
        notes: 'Canonical pin from real 23-codes/23Coins repo art. Untouchable.',
    },
    pwnglove_icon: {
        art_status: 'final', human_reviewed: true,
        reviewer: 'cory_k', reviewed_at: '2026-05-23',
        reference_image: 'docs/hakcd_title.png',
        notes: 'Canonical pin from real PWNGLOVE render. Used by TitleScene + PlaygroundScene.',
    },
    coin_0:        { art_status: 'final', human_reviewed: true, reviewer: 'cory_k', reviewed_at: '2026-05-23', reference_image: null, notes: 'Canonical pin from real 23-codes/23Coins repo coin art.' },
    coin_1:        { art_status: 'final', human_reviewed: true, reviewer: 'cory_k', reviewed_at: '2026-05-23', reference_image: null, notes: 'Canonical pin from real 23-codes/23Coins repo coin art.' },
    coin_2:        { art_status: 'final', human_reviewed: true, reviewer: 'cory_k', reviewed_at: '2026-05-23', reference_image: null, notes: 'Canonical pin from real 23-codes/23Coins repo coin art.' },
    coin_3:        { art_status: 'final', human_reviewed: true, reviewer: 'cory_k', reviewed_at: '2026-05-23', reference_image: null, notes: 'Canonical pin from real 23-codes/23Coins repo coin art.' },
    coin_0_large:  { art_status: 'final', human_reviewed: true, reviewer: 'cory_k', reviewed_at: '2026-05-23', reference_image: null, notes: 'Canonical pin (zoom variant) from real 23-codes/23Coins repo coin art.' },
    coin_1_large:  { art_status: 'final', human_reviewed: true, reviewer: 'cory_k', reviewed_at: '2026-05-23', reference_image: null, notes: 'Canonical pin (zoom variant) from real 23-codes/23Coins repo coin art.' },
    coin_2_large:  { art_status: 'final', human_reviewed: true, reviewer: 'cory_k', reviewed_at: '2026-05-23', reference_image: null, notes: 'Canonical pin (zoom variant) from real 23-codes/23Coins repo coin art.' },
    coin_3_large:  { art_status: 'final', human_reviewed: true, reviewer: 'cory_k', reviewed_at: '2026-05-23', reference_image: null, notes: 'Canonical pin (zoom variant) from real 23-codes/23Coins repo coin art.' },

    launcher_card:         { art_status: 'final', human_reviewed: true, reviewer: 'cory_k', reviewed_at: '2026-05-23', reference_image: 'docs/hakcd_title.png', notes: 'Launcher card derived from canonical title art.' },
    launcher_card_pressed: { art_status: 'final', human_reviewed: true, reviewer: 'cory_k', reviewed_at: '2026-05-23', reference_image: 'docs/hakcd_title.png', notes: 'Launcher card pressed-state derived from canonical title art.' },
    launcher_launchImage:  { art_status: 'final', human_reviewed: true, reviewer: 'cory_k', reviewed_at: '2026-05-23', reference_image: 'docs/hakcd_title.png', notes: 'Launcher splash derived from canonical title art.' },
    icon:                  { art_status: 'final', human_reviewed: true, reviewer: 'cory_k', reviewed_at: '2026-05-23', reference_image: 'docs/hakcd_title.png', notes: 'System-menu icon derived from canonical title art.' },

    // -------- REPLACE: placeholders awaiting Phase V4-V8 --------
    coin_locked: {
        art_status: 'placeholder', human_reviewed: false,
        target_replacement_version: 'v0.1.33',
        reference_image: 'docs/reference/ui/coin_vault/coin_locked.md',
        notes: 'AUDIT FAIL §3: ImageMagick `convert -size 48x48 ... draw "?"`. Primitive draw, banned by style_guide.md §10 rule #1. Hand-pixel 48x48 replacement required.',
    },
    newb_table_32_32: {
        art_status: 'placeholder', human_reviewed: false,
        target_replacement_version: 'v0.1.33',
        reference_image: 'docs/reference/characters/newb/newb_idle_south.md',
        notes: 'AUDIT FAIL §4: lossy downscale of 100x60 concept cells via `-filter point -ordered-dither o4x4 -monochrome`. Reads as wax-melted thumbprint at hardware 1:1. Hand-pixel 48x48 or 64x64 replacement required per style_guide.md §2.',
    },
    hakcd_table_24_24: {
        art_status: 'placeholder', human_reviewed: false,
        target_replacement_version: 'v0.1.34',
        reference_image: 'docs/reference/rooms/bedroom/tileset_24_24.md',
        notes: 'AUDIT FAIL §3: generated by tools/levels/build_tileset.sh via ImageMagick `-draw` primitives, with literal text labels ("MIKE TYSON", "INSERT COIN") baked into tiles. Banned by style_guide.md §10 rules #1 + #4. Hand-pixel 24x24 tileset required.',
    },
    lockpick_body: {
        art_status: 'placeholder', human_reviewed: false,
        target_replacement_version: 'v0.1.35',
        reference_image: 'docs/reference/ui/lockpick/lockpick_pope_ref.md',
        notes: 'AUDIT FAIL §3: primitive-drawn rounded rectangle with 5 vertical bars. Author against docs/lockpickmini.png (Lucas Pope ref) per style_guide.md §10.',
    },
    newb: {
        art_status: 'placeholder', human_reviewed: false,
        target_replacement_version: 'v0.1.33',
        reference_image: 'docs/reference/characters/newb/newb_portrait.md',
        notes: 'AUDIT FAIL §3: single static portrait, no expression variants. Expand to emotion frames for dialog beats per style_guide.md §2 (major character readability).',
    },

    // -------- GENERATED: synthesized, normalized, but not pro-mastered --------
    // SFX (tools/audio/sfx_synth.js etc.) — generated wavs.
    // MUSIC (keygen scraper normalized) — generated loops.
    // Both default to art_status='generated', human_reviewed=false. See
    // type-based defaults in entryFromFile() below — listing here for
    // explicitness/readability.

    // -------- DEBUG: Noble demo fixtures, not gameplay-facing --------
    background1: {
        art_status: 'debug', human_reviewed: false,
        reference_image: null,
        notes: 'Noble engine demo background fixture; not referenced by HAKCD scenes. Ships only because pdc bundles source/assets/images/. Candidate for removal.',
    },
    background2: {
        art_status: 'debug', human_reviewed: false,
        reference_image: null,
        notes: 'Noble engine demo background fixture; not referenced by HAKCD scenes. Ships only because pdc bundles source/assets/images/. Candidate for removal.',
    },
};

// ---------- Readability minimums (style_guide.md §2 + §9) ----------
// Returns required vertical-occupancy floor for a given asset id / type.
// 0.0 disables the check; 1.0 means full-screen.
function readabilityMin(id, type) {
    // Full-screen splashes / backgrounds — by definition cover the screen.
    if (id === 'title' || id === 'launcher_launchImage' || type === 'background') return 1.0;
    // System icon — own checks, not a gameplay sprite.
    if (id === 'icon') return 0.0;
    // Launcher card — UI in the launcher chrome, not in-game.
    if (id === 'launcher_card' || id === 'launcher_card_pressed') return 0.0;
    // Audio assets — readability check doesn't apply.
    if (type === 'sfx' || type === 'music') return 0.0;
    // Tilesets — per-cell check is at composition time, not per-PNG.
    if (type === 'tileset' || type === 'imagetable') {
        // Player/major-NPC imagetables: 15% per style_guide §2.
        if (id.startsWith('newb')) return 0.15;
        return 0.0;
    }
    // Static gameplay sprites — UI icons (16-24px) are exempt from §2's
    // character-scale rule; large UI elements (lockpick body) get a
    // readability floor sized to their role.
    if (id === 'lockpick_body') return 0.30;        // major UI element, ~30% of screen
    if (id === 'pwnglove_icon') return 0.40;        // hero icon on title
    if (id.startsWith('coin') && id.endsWith('_large')) return 0.50; // zoomed coin
    if (id.startsWith('coin')) return 0.13;         // 48px coin tile, ~20% vertical
    if (id === 'newb') return 0.20;                 // portrait (48x56)
    return 0.0;
}

// ---------- Per-file entry builder ----------
function entryFromFile(filePath) {
    const rel = path.relative(ROOT, filePath);
    const ext = path.extname(filePath).toLowerCase();
    const base = path.basename(filePath, ext);

    let id, type, sourcePath, sheet_w, sheet_h, target_w, target_h, frame_count;

    if (ext === '.png') {
        const tableMatch = base.match(/^(.+)-table-(\d+)-(\d+)$/);
        // Compute the Playdate-convention path (no extension, no `source/` prefix).
        sourcePath = rel.replace(/^source\//, '').replace(/\.png$/, '');

        if (tableMatch) {
            const cellW = parseInt(tableMatch[2], 10);
            const cellH = parseInt(tableMatch[3], 10);
            const { w, h } = dim(filePath);
            sheet_w = w; sheet_h = h;
            target_w = cellW; target_h = cellH;
            frame_count = (w && h) ? Math.floor(w / cellW) * Math.floor(h / cellH) : null;
            // Convention: id is base with dashes → underscores.
            id = base.replace(/-/g, '_');
            // Tileset vs character-imagetable: hakcd-table-* is a tileset;
            // newb-table-* is a character imagetable.
            type = id.startsWith('hakcd_table') ? 'tileset' : 'imagetable';
        } else {
            const { w, h } = dim(filePath);
            sheet_w = w; sheet_h = h;
            target_w = w; target_h = h;
            frame_count = 1;
            // Launcher PNGs get a `launcher_` prefix to disambiguate.
            if (rel.startsWith('source/assets/launcher/')) {
                id = 'launcher_' + base.replace(/-/g, '_');
            } else {
                id = base.replace(/-/g, '_');
            }
            type = 'image';
        }
    } else if (ext === '.wav') {
        sourcePath = rel.replace(/^source\//, '').replace(/\.wav$/, '');
        const { size } = fs.statSync(filePath);
        sheet_w = null; sheet_h = null;
        target_w = null; target_h = null;
        frame_count = null;
        if (rel.includes('/music/')) {
            type = 'music';
            id = base;
        } else if (rel.includes('/sfx/')) {
            type = 'sfx';
            id = base;
        } else if (rel.startsWith('source/assets/launcher/')) {
            // launcher/sound.wav — distinct from sfx/music
            type = 'sfx';
            id = 'launcher_sound';
        } else {
            type = 'sfx';
            id = base;
        }
        // Stash size as duration_bytes for audio (matches assets.lua convention).
        var duration_bytes = size;
    } else {
        return null;
    }

    // Pull explicit status; fall back to type-based defaults.
    const explicit = STATUS_TABLE[id];
    let art_status, human_reviewed, reviewer, reviewed_at, reference_image, target_replacement_version, notes;
    if (explicit) {
        art_status                 = explicit.art_status;
        human_reviewed             = explicit.human_reviewed;
        reviewer                   = explicit.reviewer || null;
        reviewed_at                = explicit.reviewed_at || null;
        reference_image            = explicit.reference_image !== undefined ? explicit.reference_image : null;
        target_replacement_version = explicit.target_replacement_version || null;
        notes                      = explicit.notes || '';
    } else if (type === 'sfx') {
        art_status = 'generated'; human_reviewed = false;
        reviewer = null; reviewed_at = null;
        reference_image = null; target_replacement_version = null;
        notes = 'Synthesized via tools/audio/sfx_synth.js / synth_v4_sfx.js. Normalized but not pro-mastered. Acceptable for ship; replace if pro audio pass scheduled.';
    } else if (type === 'music') {
        art_status = 'generated'; human_reviewed = false;
        reviewer = null; reviewed_at = null;
        reference_image = null; target_replacement_version = null;
        notes = 'Keygen-scraper sourced, normalized to keygen_loudness_baseline.txt. Not pro-mastered. Acceptable for ship; replace if pro audio pass scheduled.';
    } else {
        // Default for any unanticipated PNG: treat as placeholder.
        art_status = 'placeholder'; human_reviewed = false;
        reviewer = null; reviewed_at = null;
        reference_image = null; target_replacement_version = null;
        notes = 'No explicit audit verdict; default placeholder. Add an entry to STATUS_TABLE in tools/canon/generate_visual_spec.js to classify.';
    }

    const readability_min_pct_screen = readabilityMin(id, type);
    // meets_readability_min uses sheet_h (the actual on-disk pixel height)
    // for static images and the per-cell h for imagetables — the rule in
    // style_guide.md §2 measures the rendered sprite's footprint, which
    // for an imagetable is one cell.
    const measured_h = (type === 'imagetable' || type === 'tileset') ? target_h : sheet_h;
    let meets_readability_min;
    if (readability_min_pct_screen === 0.0) {
        meets_readability_min = true;
    } else if (!measured_h) {
        meets_readability_min = false;
    } else {
        meets_readability_min = (measured_h / 240) >= readability_min_pct_screen;
    }

    const entry = {
        id,
        type,
        path: sourcePath,
        target_dimensions: (target_w && target_h) ? { w: target_w, h: target_h } : null,
        sheet_dimensions:  (sheet_w  && sheet_h ) ? { w: sheet_w,  h: sheet_h  } : null,
        frame_count,
        art_status,
        human_reviewed,
        reviewer,
        reviewed_at,
        readability_min_pct_screen,
        meets_readability_min,
        reference_image,
        target_replacement_version,
        notes,
    };
    if (type === 'sfx' || type === 'music') {
        entry.duration_bytes = duration_bytes;
    }
    return entry;
}

// ---------- Collect all assets ----------
const allFiles = [
    ...walk(path.join(ROOT, 'source/images')).filter(f => f.endsWith('.png')),
    ...walk(path.join(ROOT, 'source/sounds/sfx')).filter(f => f.endsWith('.wav')),
    ...walk(path.join(ROOT, 'source/sounds/music')).filter(f => f.endsWith('.wav')),
    ...walk(path.join(ROOT, 'source/assets/launcher')).filter(f => f.endsWith('.png') || f.endsWith('.wav')),
    ...walk(path.join(ROOT, 'source/assets/images')).filter(f => f.endsWith('.png')),
];
// source/icon.png — top-level system-menu icon.
const iconPath = path.join(ROOT, 'source/icon.png');
if (fs.existsSync(iconPath)) allFiles.push(iconPath);

allFiles.sort();

const entries = {};
for (const f of allFiles) {
    const e = entryFromFile(f);
    if (e) entries[e.id] = e;
}

// ---------- Lua emit (deterministic — keys sorted alphabetically) ----------
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
        const keys = Object.keys(v).sort();
        if (keys.length === 0) return '{}';
        const parts = keys.map(k => {
            const safeKey = /^[A-Za-z_][A-Za-z0-9_]*$/.test(k) ? k : `["${luaEscape(k)}"]`;
            return padIn + safeKey + ' = ' + luaValue(v[k], indent + 1);
        });
        return '{\n' + parts.join(',\n') + '\n' + pad + '}';
    }
    return 'nil';
}

// Build the top-level table with keys sorted alphabetically.
const sortedIds = Object.keys(entries).sort();
const tableBody = sortedIds.map(id =>
    '    ' + id + ' = ' + luaValue(entries[id], 1)
).join(',\n');

const out = `-- source/data/visual_spec.lua
-- GENERATED by tools/canon/generate_visual_spec.js — do not hand-edit.
-- Re-run whenever an asset is added/removed/reclassified.
-- Phase V2 of visual recovery plan (see docs/VISUAL_PIPELINE_FAILURE_AUDIT.md §13).
--
-- This is the VISUAL CONTRACT. Phase V3 validator will enforce it. Every
-- shippable asset declares its art_status, human_reviewed sign-off,
-- target_dimensions, readability floor, reference image, and audit notes.
--
-- Status values:
--   'final'       — authored, human-reviewed, ships canonically.
--   'placeholder' — known-bad asset awaiting V4-V8 replacement.
--   'generated'   — synthesized (sfx) or scraped (music); acceptable to ship.
--   'wip'         — in active development, not ship-ready.
--   'debug'       — engine fixtures, dev-only; should not appear in release.
--
-- Reference: docs/style_guide.md §2 (character scale), §9 (hardware
-- readability), §12 (sign-off). All readability floors trace back to
-- "player sprite must occupy >= 15% of vertical screen at 400x240".

local visual_spec = {
${tableBody}
}

-- ---------- Helpers (consumed by Phase V3 validator + scenes) ----------

function visual_spec.assert_id(asset_id)
    assert(visual_spec[asset_id], "visual_spec: unknown asset id '"..tostring(asset_id).."'")
    return visual_spec[asset_id]
end

function visual_spec.is_final(asset_id)
    local s = visual_spec[asset_id]
    return s and s.art_status == 'final' and s.human_reviewed == true
end

function visual_spec.placeholders()
    local out = {}
    for k, v in pairs(visual_spec) do
        if type(v) == 'table' and v.art_status == 'placeholder' then
            table.insert(out, k)
        end
    end
    table.sort(out)
    return out
end

function visual_spec.failing_readability()
    local out = {}
    for k, v in pairs(visual_spec) do
        if type(v) == 'table' and v.meets_readability_min == false then
            table.insert(out, k)
        end
    end
    table.sort(out)
    return out
end

_G.visual_spec = visual_spec
return visual_spec
`;

fs.writeFileSync(OUT, out);
console.log(`Wrote ${OUT}`);
const byStatus = {};
for (const id of sortedIds) {
    const s = entries[id].art_status;
    byStatus[s] = (byStatus[s] || 0) + 1;
}
console.log(`  ${sortedIds.length} assets declared:`, byStatus);
const failing = sortedIds.filter(id => entries[id].meets_readability_min === false);
console.log(`  ${failing.length} failing readability_min:`, failing);
