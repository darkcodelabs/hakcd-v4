#!/usr/bin/env node
'use strict';
// tools/canon/generate_assets_manifest.js
//
// Phase 4 of canon-first migration. Walks source/images/ + source/sounds/
// for every shippable asset, cross-references canon scenes/characters to
// populate used_by, emits source/data/assets.lua.
//
// Re-run whenever an asset is added/removed. Phase 7 validator confirms
// every asset.path actually exists on disk and that frame counts match
// AnimatedSprite addState ranges.

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ROOT = path.resolve(__dirname, '../..');
const OUT  = path.join(ROOT, 'source/data/assets.lua');

// ---------- Walk source/images recursively ----------
function walk(dir, results) {
    results = results || [];
    for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
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

const imagesDir = path.join(ROOT, 'source/images');
const soundsDir = path.join(ROOT, 'source/sounds');

const assets = [];

// ---------- Imagetables (sprite sheets) ----------
// Convention: `<name>-table-<W>-<H>.png` — frame_count = (img_w/W) * (img_h/H)
const imageFiles = walk(imagesDir).filter(f => f.endsWith('.png'));
for (const f of imageFiles) {
    const rel = path.relative(ROOT, f);
    const base = path.basename(f, '.png');
    const id = base.replace(/-/g, '_');
    const sourcePath = rel.replace(/^source\//, '').replace(/\.png$/, '');
    const { w, h } = dim(f);

    // Imagetable detection
    const tableMatch = base.match(/^(.+)-table-(\d+)-(\d+)$/);
    if (tableMatch) {
        const cellW = parseInt(tableMatch[2], 10);
        const cellH = parseInt(tableMatch[3], 10);
        const frame_count = (w && h) ? Math.floor(w / cellW) * Math.floor(h / cellH) : null;
        assets.push({
            id,
            type: 'imagetable',
            path: sourcePath,
            file: rel,
            width: cellW,
            height: cellH,
            sheet_width: w,
            sheet_height: h,
            frame_count,
            used_by_scene: id.includes('newb_table') ? ['BedroomScene', 'PlaygroundScene', 'SpriteTestScene'] : [],
            used_by_character: id.includes('newb_table') ? 'newb' : null,
            priority: id.includes('newb_table') ? 'critical' : 'high'
        });
        continue;
    }

    // Static image (single PNG)
    let used_by_scene = [];
    if (id === 'title')          used_by_scene = ['TitleScene'];
    if (id === 'pwnglove_icon')  used_by_scene = ['TitleScene', 'PlaygroundScene'];
    if (id.startsWith('coin_'))  used_by_scene = ['CoinVaultScene'];
    if (id === 'icon')           used_by_scene = ['_launcher_'];
    if (id === 'card')           used_by_scene = ['_launcher_'];
    if (id === 'card_pressed')   used_by_scene = ['_launcher_'];
    if (id === 'launchImage')    used_by_scene = ['_launcher_'];
    if (id === 'lockpick_body')  used_by_scene = ['LockpickScene'];
    if (id === 'pwnglove_playground') used_by_scene = ['PlaygroundScene'];
    if (id === 'newb')           used_by_scene = ['BedroomScene', 'PhoneScene', 'CoinVaultScene', 'LockpickScene'];

    assets.push({
        id,
        type: 'image',
        path: sourcePath,
        file: rel,
        width: w,
        height: h,
        frame_count: 1,
        used_by_scene,
        used_by_character: id.startsWith('newb') ? 'newb' : null,
        priority: used_by_scene.length > 0 ? 'critical' : 'low'
    });
}

// ---------- Sounds (sfx + music) ----------
if (fs.existsSync(soundsDir)) {
    const soundFiles = walk(soundsDir).filter(f => f.endsWith('.wav'));
    for (const f of soundFiles) {
        const rel = path.relative(ROOT, f);
        const base = path.basename(f, '.wav');
        const id = base;
        const sourcePath = rel.replace(/^source\//, '').replace(/\.wav$/, '');
        const isMusic = rel.includes('music');
        let used_by_scene = [];
        if (isMusic) {
            if (id === 'title_loop')      used_by_scene = ['TitleScene'];
            if (id === 'bedroom_loop')    used_by_scene = ['BedroomScene', 'ComputerScene', 'ModemScene', 'PhoneScene'];
            if (id === 'playground_loop') used_by_scene = ['PlaygroundScene'];
            if (id === 'tyson_loop')      used_by_scene = ['TysonScene'];
            if (id === 'coinvault_loop')  used_by_scene = ['CoinVaultScene'];
        } else {
            if (id.startsWith('lockpick_'))    used_by_scene = ['LockpickScene'];
            if (id.startsWith('tyson_'))       used_by_scene = ['TysonScene'];
            if (id.startsWith('coin_'))        used_by_scene = ['CoinVaultScene'];
            if (id.startsWith('step_'))        used_by_scene = ['BedroomScene', 'PlaygroundScene'];
            if (id === 'pwnglove_boot')        used_by_scene = ['ComputerScene'];
        }
        const stat = fs.statSync(f);
        assets.push({
            id,
            type: isMusic ? 'music' : 'sfx',
            path: sourcePath,
            file: rel,
            width: null,
            height: null,
            duration_bytes: stat.size,
            used_by_scene,
            used_by_character: null,
            priority: used_by_scene.length > 0 ? 'high' : 'low'
        });
    }
}

// ---------- Launcher tile entries (live at source/assets/launcher/) ----------
const launcherDir = path.join(ROOT, 'source/assets/launcher');
if (fs.existsSync(launcherDir)) {
    for (const ent of fs.readdirSync(launcherDir, { withFileTypes: true })) {
        if (ent.isFile() && ent.name.endsWith('.png')) {
            const f = path.join(launcherDir, ent.name);
            const rel = path.relative(ROOT, f);
            const base = path.basename(f, '.png');
            const { w, h } = dim(f);
            assets.push({
                id: `launcher_${base.replace(/-/g, '_')}`,
                type: 'image',
                path: rel.replace(/^source\//, '').replace(/\.png$/, ''),
                file: rel,
                width: w,
                height: h,
                frame_count: 1,
                used_by_scene: ['_launcher_'],
                used_by_character: null,
                priority: 'critical'
            });
        }
    }
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

const out = `-- source/data/assets.lua
-- GENERATED by tools/canon/generate_assets_manifest.js — do not hand-edit.
-- Re-run whenever an asset is added/removed.
-- Phase 4 of canon-first migration plan.
--
-- Every shippable asset declared with id, type, path, dimensions,
-- frame_count, used_by_scene, used_by_character, priority.
-- Phase 7 validator confirms paths resolve + frame counts match
-- AnimatedSprite addState ranges.

local assets = ${luaValue(assets, 0)}

_G.assets_manifest = assets
return assets
`;

fs.writeFileSync(OUT, out);
console.log(`Wrote ${OUT}`);
const byType = {};
for (const a of assets) byType[a.type] = (byType[a.type] || 0) + 1;
console.log(`  ${assets.length} assets:`, byType);
