#!/usr/bin/env node
'use strict';
// tools/bible/parse_bible.js
//
// Parse docs/HAKCD_story_bible_v0.1.md into a structured JSON manifest.
// Output: source/data/bible_parsed.json
//
// Single source-of-truth read for downstream phases (canon, continuity,
// asset manifest, etc). NEVER hand-edit bible_parsed.json — re-run this
// when the bible markdown changes.

const fs = require('fs');
const path = require('path');

const BIBLE = process.argv[2] || path.resolve(__dirname, '../../docs/HAKCD_story_bible_v0.1.md');
const OUT   = process.argv[3] || path.resolve(__dirname, '../../source/data/bible_parsed.json');

const raw = fs.readFileSync(BIBLE, 'utf8');

// ---------- 1. Split by `## ` top-level sections ----------

const SECTION_RE = /^## (.+)$/gm;
const sections = {};
const matches = [...raw.matchAll(SECTION_RE)];
for (let i = 0; i < matches.length; i++) {
    const name = matches[i][1].trim();
    const start = matches[i].index + matches[i][0].length;
    const end = (i + 1 < matches.length) ? matches[i + 1].index : raw.length;
    sections[name] = raw.slice(start, end).trim();
}

// ---------- 2. Top-level facts ----------

const titleMatch = raw.match(/^# (.+?)(?:\n|:)/m);
const game_title = titleMatch ? titleMatch[1].replace(/[:].*$/, '').trim() : 'HAKCD';

// Genre + tone derived from LOGLINE + SETTING text (heuristic).
const logline = (sections['LOGLINE'] || '').replace(/\s+/g, ' ').trim();
const setting = (sections['SETTING'] || '').replace(/\s+/g, ' ').trim();
const structure = (sections['STRUCTURE'] || '').replace(/\s+/g, ' ').trim();

const core_premise = logline;
const genre = 'cyberpunk-phreaker';
const tone = 'noir-grounded-comic-relief';

// Timeline = first explicit date range in SETTING.
const timelineMatch = setting.match(/([A-Z][a-z]+ \d{4}.*?\d{4}|\d{4}.+?\d{4})/);
const timeline = timelineMatch ? timelineMatch[1] : '1998-1999';

// ---------- 3. Characters (main + supporting) ----------

function takeCharacter(sectionName, id_hint) {
    const txt = sections[sectionName];
    if (!txt) return null;
    // Voice line — first sentence often summarizes
    const firstPara = txt.split(/\n\n/)[0].replace(/\s+/g, ' ').trim();
    return { id: id_hint, source_section: sectionName, summary: firstPara };
}

const main_character = takeCharacter('PROTAGONIST', 'newb');
const antagonist = takeCharacter('ANTAGONIST: REDHOOK', 'redhook');
const mentor = takeCharacter('THE MENTOR / THE DAEMON', 'mentor');

// CAST LIST — numbered list "1. **NPC Name.** description"
const cast_raw = sections['CAST LIST (15 named NPCs across 4 acts + coda)'] || '';
const cast = [];
const CAST_RE = /^(\d+)\.\s+\*\*([^*]+?)\.\*\*\s+(.+?)(?=\n\d+\.\s+\*\*|\n###|\n## |\n---|$)/gms;
for (const m of cast_raw.matchAll(CAST_RE)) {
    const num = parseInt(m[1], 10);
    const name = m[2].trim();
    const desc = m[3].replace(/\s+/g, ' ').trim();
    // Derive id: lowercase, alnum + underscore, strip parenthetical
    const id = name.toLowerCase()
        .replace(/\(.*?\)/g, '')
        .replace(/[^a-z0-9]+/g, '_')
        .replace(/^_+|_+$/g, '');
    cast.push({ num, id, name, description: desc });
}

const supporting_characters = cast;

// ---------- 4. Scenes ----------

const scene_raw = sections['SCENE LIST'] || '';
// Each scene = "**SC0N. Name (paren).** description"
const SCENE_RE = /\*\*(SC\d+)\.\s+([^*]+?)\.\*\*\s+(.+?)(?=\n\*\*SC\d+\.|\n###|\n## |\n---|$)/gs;
const scenes = [];
let current_act_for_scene = null;
const lines = scene_raw.split('\n');
let bodyCursor = 0;
const ACT_HEAD = /^### (Act \d+:.+|Coda)/i;
const SC_HEAD  = /\*\*(SC\d+)\.\s+([^*]+?)\.\*\*\s+(.+)/;
let buf = '';
let activeScene = null;
const flushScene = () => {
    if (activeScene) {
        activeScene.description = activeScene.description.replace(/\s+/g, ' ').trim();
        scenes.push(activeScene);
    }
};
for (const line of lines) {
    const actHead = line.match(ACT_HEAD);
    if (actHead) {
        current_act_for_scene = actHead[1].trim();
        continue;
    }
    const scHead = line.match(SC_HEAD);
    if (scHead) {
        flushScene();
        const sid = scHead[1].toLowerCase();         // sc01
        const sname = scHead[2].trim();
        activeScene = {
            id: sid,
            name: sname,
            act: current_act_for_scene,
            description: scHead[3].trim()
        };
    } else if (activeScene && line.trim().length > 0) {
        activeScene.description += ' ' + line.trim();
    }
}
flushScene();

// ---------- 5. Rooms (synonym of scenes in HAKCD bible) ----------

const rooms = scenes.map(s => ({
    id: s.id,
    name: s.name,
    act: s.act
}));

// ---------- 6. Interactables from scene descriptions + item list ----------

const ITEM_RE = /^- \*\*(.+?)\*\*\s*(?::|—|-)?\s*(.+)$/gm;
const item_raw = sections['ITEM LIST (inventory)'] || '';
const items = [];
for (const m of item_raw.matchAll(ITEM_RE)) {
    const name = m[1].replace(/\s*\([^)]*\)/g, '').trim();
    const id = name.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
    items.push({ id, name, description: m[2].replace(/\s+/g, ' ').trim() });
}

// Interactables = unique nouns extracted from scene descriptions (heuristic).
// Pulls likely object words after "Computer, modem, phone, bed" patterns.
const INTERACT_HINTS = new Set();
for (const s of scenes) {
    const txt = s.description.toLowerCase();
    // common phreaker-era objects
    for (const noun of ['computer', 'modem', 'phone', 'bed', 'desk', 'payphone',
                        'pedestal', 'cabinet', 'arcade cabinet', 'workbench',
                        'badge', 'cdrom', 'cd-rom', 'floppy', 'server rack',
                        'door', 'keypad', 'tv', 'crt', 'garage door',
                        'lockpick', 'red box', 'blue box', 'beige box']) {
        if (txt.includes(noun)) {
            INTERACT_HINTS.add(noun.replace(/[^a-z0-9]+/g, '_'));
        }
    }
}
const interactables = [...INTERACT_HINTS].map(id => ({ id }));

// ---------- 7. Acts ----------

const acts = [];
for (const key of Object.keys(sections)) {
    const m = key.match(/^ACT (\d+):\s+(.+)$/);
    if (m) {
        acts.push({
            act_num: parseInt(m[1], 10),
            title: m[2].trim(),
            section_name: key,
            summary: sections[key].split('\n\n')[0].replace(/\s+/g, ' ').trim()
        });
    }
}
if (sections['CODA (post-credits, unlocks after first completion)']) {
    acts.push({
        act_num: 5,
        title: 'Coda',
        section_name: 'CODA (post-credits, unlocks after first completion)',
        summary: sections['CODA (post-credits, unlocks after first completion)']
            .split('\n\n')[0].replace(/\s+/g, ' ').trim()
    });
}

// ---------- 8. Tool progression ----------

const tool_raw = sections['TOOL PROGRESSION'] || '';
const tool_acts = [];
const TOOL_RE = /^- \*\*Act (\d+):\*\*\s+(.+)$/gm;
for (const m of tool_raw.matchAll(TOOL_RE)) {
    const act_num = parseInt(m[1], 10);
    const tools_list = m[2].split(/,\s*/).map(t => t.replace(/\(.*?\)/g, '').trim());
    tool_acts.push({ act_num, tools: tools_list });
}

// ---------- 9. Skill gate map (puzzle moments) ----------

const skill_raw = sections['SKILL GATE MAP'] || '';
const skill_gates = [];
const ROW_RE = /^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|$/gm;
let firstRowSeen = false;
for (const m of skill_raw.matchAll(ROW_RE)) {
    const beat = m[1].trim();
    if (beat === 'Beat' || beat.startsWith('---')) continue;
    skill_gates.push({
        beat,
        required_tool: m[2].trim(),
        optional_tools: m[3].trim() === 'none' ? [] : m[3].trim().split(/,\s*/)
    });
}

// ---------- 10. Recurring motifs ----------

const recurring_motifs = [];
if (setting.toLowerCase().includes('icq')) recurring_motifs.push('ICQ uh-oh sound');
if (setting.toLowerCase().includes('aol')) recurring_motifs.push('AOL chrome');
if (raw.toLowerCase().includes('mom yells')) recurring_motifs.push("Mom's phone-bill interrupt");
if (raw.toLowerCase().includes('mentor')) recurring_motifs.push("Mentor voice / DEADLINE BBS");
if (raw.includes('crank')) recurring_motifs.push('Crank as primary input device');
if (raw.toLowerCase().includes('pwnglove')) recurring_motifs.push('PWNGLOVE multi-tool');
if (raw.toLowerCase().includes('23 c0ins') || raw.includes('23 C0iNS')) recurring_motifs.push('23 C0iNS collection');

// ---------- 11. Win / fail conditions ----------

const release_raw = sections['REPLAY AND BRANCHING'] || '';
const win_condition = 'Publish proof of Project HOLLOWPOINT before Aegis activates the BGP backdoor (mid-1999).';
const fail_conditions = [
    'Run out of in-game weeks before Aegis activation',
    'RedHook completes the trace during Act 4 confrontation',
    'Mom catches you with a phone bill over $50 and you cannot pay her back (Act 1 finale)',
    'Fail lockpick + Bell pedestal three times (neighbor lights, retreat)'
];

// ---------- 12. UI requirements ----------

const ui_requirements = [
    'Crank as primary input (lockpick, dial, charge, scroll)',
    'D-pad walking + facing in walkable rooms (Bedroom, Playground)',
    'A = confirm / interact, B = back / cancel',
    'System menu items: "pwnglove mode" + "back to story"',
    'Dialog overlay with newb portrait + typewriter text',
    'BBS terminal: monospace black-on-white scrolling',
    'AOL chrome (Act 2): dominant in #warez_lobby / #cyber_lounge / #phreak_kingdom / #h_p_v_a_c / #private_chan_7',
    'ICQ overlay popups with "uh-oh" SFX',
    'Coin Vault: 4x6 grid + sidebar with closeup',
    'Tyson cabinet: digit-entry UI for 007-373-5963',
    'Lockpick UI matching docs/lockpickmini.png (Lucas Pope density)'
];

// ---------- 13. Required animations (inferred) ----------

const required_animations = [
    { id: 'newb_idle_south', character: 'newb' },
    { id: 'newb_walk_south', character: 'newb' },
    { id: 'newb_idle_north', character: 'newb' },
    { id: 'newb_walk_north', character: 'newb' },
    { id: 'newb_idle_east',  character: 'newb' },
    { id: 'newb_walk_east',  character: 'newb' },
    { id: 'newb_idle_west',  character: 'newb' },
    { id: 'newb_walk_west',  character: 'newb' },
    { id: 'newb_interact',   character: 'newb' },
    { id: 'newb_surprised',  character: 'newb' },
    { id: 'terminal_typewriter', character: 'system' },
    { id: 'lockpick_pin_set',    character: 'system' },
    { id: 'tyson_cabinet_attract', character: 'system' },
    { id: 'coin_vault_zoom',     character: 'system' },
    { id: 'crt_collapse',        character: 'system' }
];

// ---------- 14. PWNGLOVE + 23 C0iNS — mechanic spec carve-outs ----------

const pwnglove_raw = sections['PWNGLOVE'] || '';
const pwnglove_yaml = (pwnglove_raw.match(/```yaml\n([\s\S]+?)\n```/) || [])[1] || '';
const coins_raw = sections['23 C0iNS'] || '';

// ---------- 15. Output JSON ----------

const out = {
    _meta: {
        generated_by: 'tools/bible/parse_bible.js',
        source: path.relative(path.resolve(__dirname, '../..'), BIBLE),
        timestamp: new Date().toISOString(),
        do_not_hand_edit: true
    },
    game_title,
    genre,
    tone,
    core_premise,
    timeline,
    structure_summary: structure,
    main_character,
    antagonist,
    mentor,
    supporting_characters,
    chapters: acts,
    scenes,
    rooms,
    interactables,
    items,
    tool_progression: tool_acts,
    skill_gates,
    required_animations,
    ui_requirements,
    win_condition,
    fail_conditions,
    recurring_motifs,
    pwnglove_yaml_block: pwnglove_yaml,
    coins_raw_section: coins_raw.replace(/\s+/g, ' ').trim().slice(0, 800)
};

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify(out, null, 2) + '\n');
console.log(`Wrote ${OUT}`);
console.log(`  ${scenes.length} scenes, ${supporting_characters.length} NPCs, ${acts.length} acts, ${items.length} items, ${skill_gates.length} skill gates`);
