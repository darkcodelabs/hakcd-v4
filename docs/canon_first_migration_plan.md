# hakcd-v4 → Canon-First Migration Plan

This plan reconciles the **bible → canon → continuity → manifests → skeleton → assets → validation** build order against the current `hakcd-v4` state, which was built backward (stack-first sprint with 5 parallel agents). Nothing here throws v4 — it retrofits canon as the single source of truth and pulls the manifests out of the code that's already shipped.

Last release: [v0.1.10](https://github.com/darkcodelabs/hakcd-v4/releases/tag/v0.1.10) (15 commits past foundation).

---

## What's already present (against the 13 prescribed phases)

| Phase | Status | Notes |
|---|---|---|
| 1. Parse Game Bible | ⚠️ Partial | Bible exists at `/home/hakcer/projects/personal/hakcd/sdk_data/story_bible.md` + `docs/HAKCD_story_bible_v0.1.md`. Never machine-parsed into JSON for v4. |
| 2. Canon File | ❌ Missing | No `source/data/canon.lua`. Character/room/object/scene ids live as bare strings across `world.ldtk`, scene `.lua` files, `coins.json`. |
| 3. Continuity Map | ⚠️ Partial | `Progression.lua` holds runtime state (coins / inventory / acts / flags), but no `continuity.lua` declares scene order, dialogue unlock rules, flag-set rules. |
| 4. Asset Manifest | ⚠️ Partial | `tools/asset_validator.sh` enforces 1-bit + outline, but no `source/data/assets.lua` enumerates every PNG with width/height/frame-count/used-by. |
| 5. Animation Manifest | ⚠️ Partial | `Newb.lua` declares 10 states inline. Other future sprites would each invent their own pattern. No `animations.lua` global registry. |
| 6. Room Manifest | ⚠️ Partial | `world.ldtk` carries layout + entities. No `rooms.lua` wrapper exposing walkable bounds / exits / spawn / NPCs / camera per room id. |
| 7. Playable Skeleton First | ✅ Done backward | v0.1.0 IS the playable skeleton. Built before canon, but it works. |
| 8. Sprite Sheets | ⚠️ Partial | One sheet (`newb-table-32-32.png`) generated. No `npc-*` / `ui-*` / per-object sheets. |
| 9. Backgrounds | ⚠️ Partial | LDtk tilemap renders both rooms. `playground_room_overview.png` concept exists; not procedurally generated per room manifest. |
| 10. Integrate Final Assets | ⚠️ Partial | Canonical pin assets wired (title/glove/coin_0..3). Bedroom + Playground bgs still tile-grid; no per-room hand-art. |
| 11. Continuity Validation | ❌ Missing | No validator confirms scene→room→asset→dialogue id graph is closed. Strings can drift. |
| 12. Playtest Script | ❌ Missing | No `tools/playtest_checklist.md`. Smoke test never formalized. |
| 13. Hardware Optimization | ⚠️ Partial | Path-equality check in `start_scene_music` avoids restart on transition. No formal allocation-in-update audit. |

**Verdict:** v4 is a working skeleton (phase 7) that skipped 1-6 + 11-12. The next migration converts already-shipped code into canon-driven structure WITHOUT a rebuild.

---

## Migration plan — extract canon from what already ships, then enforce

Each step is small, ships as its own version bump (v0.1.11 → v0.1.13+), and leaves the running game playable at every commit. The endpoint is: every id in every scene resolves through canon, and a validator pass fails the build if drift creeps in.

### Step 1 — Bible re-ingest into structured JSON (v0.1.11)
**File:** `source/data/bible_parsed.json`
**Reproducer:** `tools/bible/parse_bible.js`
**Source:** `/home/hakcer/projects/personal/hakcd/sdk_data/story_bible.md`

Extract via parser (markdown → JSON). Fields per phase-1 prompt:
- game_title, genre, tone, core_premise
- main_character, supporting_characters[]
- locations[] (with id)
- timeline[]
- chapters[], scenes[], rooms[]
- interactable_objects[]
- dialogue_moments[], puzzle_moments[]
- required_animations[]
- ui_requirements[]
- win_condition, fail_conditions[]
- recurring_visual_motifs[]

JSON is read-only ground truth. Subsequent steps consume this.

### Step 2 — Generate `canon.lua` from bible JSON (v0.1.12)
**File:** `source/data/canon.lua`
**Reproducer:** `tools/canon/generate_canon.js`

Walks the parsed bible + cross-references current scene files + LDtk entities. Emits:

```lua
return {
    characters = {
        newb         = { id='newb', portrait='portraits/newb', sprite_table='images/newb-table-32-32' },
        mom          = { id='mom', portrait=nil, off_screen=true },
        phractal     = { id='phractal', portrait=nil, bbs_handle=true },
        -- ...all 15 NPCs from bible
    },
    rooms = {
        sc01_bedroom = { id='sc01_bedroom', ldtk_level='Bedroom', display='Bedroom' },
        playground   = { id='playground', ldtk_level='Playground', display='PWNGLOVE MODE' },
        -- ...
    },
    scenes = {
        TitleScene      = { id='TitleScene', class='TitleScene' },
        BedroomScene    = { id='BedroomScene', class='BedroomScene', room='sc01_bedroom' },
        ComputerScene   = { id='ComputerScene', class='ComputerScene', room='sc01_bedroom', parent='BedroomScene' },
        -- ...all 10 scenes
    },
    objects = {
        computer = { id='computer', hotspot=true, room='sc01_bedroom', launches='ComputerScene' },
        modem    = { id='modem',    hotspot=true, room='sc01_bedroom', launches='ModemScene' },
        phone    = { id='phone',    hotspot=true, room='sc01_bedroom', launches='PhoneScene' },
        bed      = { id='bed',      hotspot=true, room='sc01_bedroom', launches=nil, sleeps=true },
        lockpick_station = { id='lockpick_station', hotspot=true, room='playground', launches='LockpickScene' },
        tyson_cabinet    = { id='tyson_cabinet',    hotspot=true, room='playground', launches='TysonScene' },
        coin_vault       = { id='coin_vault',       hotspot=true, room='playground', launches='CoinVaultScene' },
        -- ...
    },
    dialogue_ids = {
        mom_intro         = { id='mom_intro', speaker='mom', triggered_by='phone' },
        bbs_login_success = { id='bbs_login_success', speaker='system', triggered_by='computer' },
        -- ...
    },
    state_flags = {
        tyson_unlock           = { id='tyson_unlock', persisted=true, set_by={'TysonScene'}, read_by={'TysonScene','BedroomScene'} },
        pwnglove_mode_complete = { id='pwnglove_mode_complete', persisted=true, set_by={'PlaygroundScene'}, read_by={'PlaygroundScene'} },
        current_act            = { id='current_act', persisted=true, default=1 },
        -- ...
    },
    animation_names = {
        newb_idle_south  = { id='newb_idle_south',  state='idle_south',  frames={1,2},    tickStep=30 },
        newb_walk_south  = { id='newb_walk_south',  state='walk_south',  frames={3,4,5,6}, tickStep=6 },
        -- ...
    },
    asset_paths = {
        title          = 'images/title',
        pwnglove_icon  = 'images/pwnglove_icon',
        coin_0         = 'images/coins/coin_0',
        coin_0_large   = 'images/coins/coin_0_large',
        newb_table     = 'images/newb-table-32-32',
        -- ...all 21 PNGs
    },
}
```

**Rule:** every code site that references an id must read it from `canon.characters.newb.id` (etc.), not from a bare string. Migration runs grep over existing scenes to swap bare string ids for canon lookups.

### Step 3 — Generate `continuity.lua` from canon (v0.1.13)
**File:** `source/data/continuity.lua`
**Reproducer:** `tools/canon/generate_continuity.js`

```lua
return {
    scenes = {
        {
            id              = 'TitleScene',
            room            = nil,
            required_flags  = {},
            sets_flags      = {},
            characters      = {'newb'},
            objects         = {},
            transitions_to  = { 'BedroomScene' },
        },
        {
            id              = 'BedroomScene',
            room            = 'sc01_bedroom',
            required_flags  = {},
            sets_flags      = {},
            characters      = {'newb', 'mom'},   -- mom off-screen via phone
            objects         = {'computer', 'modem', 'phone', 'bed'},
            transitions_to  = { 'ComputerScene', 'ModemScene', 'PhoneScene', 'PlaygroundScene' },
        },
        -- ...
    },
    scene_order = { 'TitleScene', 'BedroomScene', 'PlaygroundScene', ... },
    flag_rules = {
        tyson_unlock_changes_playground = {
            condition = 'flag tyson_unlock == true',
            effect    = 'PlaygroundScene shows TYSON banner on entry',
        },
    },
}
```

Existing `Progression.lua` keeps runtime read/write, but its set sites must check the continuity rule (assert flag is declared, assert set_by names current scene).

### Step 4 — Pull `assets.lua` manifest from validator + LDtk + sprite (v0.1.14)
**File:** `source/data/assets.lua`
**Reproducer:** `tools/canon/generate_assets_manifest.js`

Walks `source/images/`, `source/sounds/`, LDtk entity refs, current scene file imagetable references. Emits one entry per asset:

```lua
return {
    {
        id            = 'title',
        type          = 'image',
        path          = 'images/title',
        width         = 400, height = 240,
        frame_count   = 1,
        used_by_scene = { 'TitleScene' },
        priority      = 'critical',
    },
    {
        id            = 'newb_table',
        type          = 'imagetable',
        path          = 'images/newb-table-32-32',
        width         = 32, height = 32,
        frame_count   = 26,
        animation_names = { 'newb_idle_south', 'newb_walk_south', ... },
        used_by_character = 'newb',
        used_by_scene    = { 'BedroomScene', 'PlaygroundScene', 'SpriteTestScene' },
        priority         = 'critical',
    },
    -- ...
}
```

### Step 5 — Pull `animations.lua` from Newb.lua (and future sprites) (v0.1.15)
**File:** `source/data/animations.lua`
**Reproducer:** `tools/canon/generate_animations_manifest.js`

```lua
return {
    newb = {
        idle_south = { frames={1,2},   frameDuration=30, loop=true,  fallback=nil },
        walk_south = { frames={3,4,5,6}, frameDuration=6, loop=true,  fallback='idle_south' },
        idle_north = { frames={7,12},   frameDuration=30, loop=true,  fallback=nil },
        walk_north = { frames={8,9,10,11}, frameDuration=6, loop=true, fallback='idle_north' },
        -- ...
        interact   = { frames={25},     frameDuration=30, loop=false, fallback='idle_south', blocks_input=true },
        surprised  = { frames={26},     frameDuration=30, loop=false, fallback='idle_south', blocks_input=false },
    },
    -- npc + object animation entries land here when those sprites land
}
```

`Newb.lua:init` reads from this manifest instead of inlining addState calls. Wrapper invariant for hand-edit pixel art replacement.

### Step 6 — `rooms.lua` extracted from LDtk world (v0.1.16)
**File:** `source/data/rooms.lua`
**Reproducer:** `tools/canon/generate_rooms_manifest.js`

```lua
return {
    sc01_bedroom = {
        id             = 'sc01_bedroom',
        ldtk_level     = 'Bedroom',
        background     = nil,   -- rendered via LDtk tilemap, not single bg
        walkable_bounds= { x=8, y=14, w=392, h=200 },
        exits          = {
            { from='bed', to_scene='PlaygroundScene' },
        },
        spawn_points   = {
            { id='player_spawn', x=200, y=160 },
        },
        interactable_objects = { 'computer', 'modem', 'phone', 'bed' },
        npcs           = { 'mom' },   -- via phone, off-screen
        camera_behavior= 'static',
        ambient_animation_objects = {},
    },
    playground = {
        id             = 'playground',
        ldtk_level     = 'Playground',
        walkable_bounds= { x=8, y=14, w=392, h=200 },
        exits          = {
            -- system menu "back to story" handles return
        },
        spawn_points   = {
            { id='player_spawn', x=200, y=180 },
        },
        interactable_objects = { 'lockpick_station', 'tyson_cabinet', 'coin_vault', 'rfid_pedestal', 'payphone', 'ir_wall', 'gravity_arena', 'subghz_tuner', 'portal_pedestal' },
        npcs           = {},
        camera_behavior= 'static',
        ambient_animation_objects = {},
    },
}
```

### Step 7 — Continuity validator (v0.1.17)
**File:** `tools/canon/validate_continuity.sh`
**Hook:** runs in `make all` before pdc, alongside `asset_validator.sh`.

Checks (fails build on any):
- Every scene in `continuity.lua` references a room in `rooms.lua`
- Every room references assets that exist in `assets.lua` (and on disk)
- Every animation in `animations.lua` references frames within the asset's frame_count
- Every dialogue id references a character in `canon.characters`
- Every `state_flags` entry has at least one `set_by` site
- Every `state_flags` entry has at least one `read_by` site
- Every character in canon appears in at least one scene's `characters` list before being read by a scene
- Every puzzle's `required_inventory` items have a `pickup_item` hotspot somewhere upstream in `scene_order`
- Every `transitions_to` target is a defined scene

If validator fires, build halts with specific id + line ref.

### Step 8 — Migrate existing scenes to read canon (v0.1.18)
Sweep current scenes:
- `BedroomScene.lua`: `if id == 'bed' then` becomes `if id == canon.objects.bed.id then`
- Hotspot routing: `Noble.transition(LockpickScene)` becomes `Noble.transition(_G[canon.objects.lockpick_station.launches])`
- `TysonScene`: `flags.tyson_unlock = true` becomes `Progression.set_flag(canon.state_flags.tyson_unlock.id, true)`
- `Newb.lua`: inline `addState` swaps to loop over `canon.animation_names` for newb

After this, grep `git grep -E "'[a-z_]+_scene|'computer'|'modem'|'phone'|'bed'"` should return zero hits in `source/scenes/` — all string ids resolve through canon.

### Step 9 — Playtest checklist (v0.1.19)
**File:** `tools/playtest_checklist.md`

```markdown
# HAKCD playtest walkthrough

## v0.1.X smoke (every release)

1. Boot title splash. A → BedroomScene.
   - Expected: bedroom_loop music starts, newb spawns at player_spawn (200, 160), 4 hotspots visible.
2. Walk to computer. A.
   - Expected: ComputerScene loads with DEADLINE BBS terminal, typewriter boot, A advances pages, B returns to BedroomScene.
   - Music continuity: bedroom_loop continues (aliased in manifest).
3. Walk to modem. A.
   - Expected: ModemScene war-dialer animation, 14 steps.
4. Walk to phone. A.
   - Expected: PhoneScene Mom dialog, 5 lines verbatim from bible.
5. Walk to bed. A.
   - Expected: transition to PlaygroundScene.
6. Walk to TYSON cabinet. A.
   - Expected: TysonScene digit entry. Crank scrolls 0-9, A commits each digit.
7. Enter `007-373-5963`.
   - Expected: TYSON MODE banner, GFXP flicker, save_state.tyson_unlock=true persisted.
8. Sideload again. Verify Tyson banner persists in bedroom on subsequent runs.
9. Walk to lockpick station. A.
   - Expected: LockpickScene loads. Music silenced. 5-pin Lucas Pope UI.
10. Walk to coin vault. A.
    - Expected: 24-card grid. Coins 0-3 real art. 4-23 locked placeholders.
11. System menu → "pwnglove mode".
    - Expected: PlaygroundScene loads regardless of which scene was active.
12. System menu → "back to story".
    - Expected: returns to TitleScene with state preserved.

## Failure cases to verify

- No scene crashes pdc compile (`make all` clean)
- No imagetable references missing frames
- No music file path 404s (silent fallback OK, hard error not OK)
- No dialogue references a character outside canon

## Performance checks

- 30 FPS steady on hardware (verify with Noble.showFPS = true in main.lua)
- No allocation spike on scene transition (gc time < 16ms)
- LDtk tilemap loads once per scene, not per frame
```

### Step 10 — Hardware optimization pass (v0.1.20)
Audit:
- No `gfx.image.new` inside any scene's `update()`
- No `imagetable.new` outside `init()` / `enter()`
- Timer cleanup in `exit()` for every scene that creates timers
- Sprite count audit per scene (<50 typical)
- Collide-rect simplicity (rectangles only, no polygon)
- Debug overlay toggleable via crank-dock or system menu

---

## Ordering — ship per step, validator gates every build from Step 7 on

| Tag | Step | Files added |
|---|---|---|
| v0.1.11 | bible_parsed.json + parser | source/data/bible_parsed.json + tools/bible/ |
| v0.1.12 | canon.lua + generator | source/data/canon.lua + tools/canon/ |
| v0.1.13 | continuity.lua + generator | source/data/continuity.lua |
| v0.1.14 | assets.lua manifest | source/data/assets.lua |
| v0.1.15 | animations.lua manifest | source/data/animations.lua |
| v0.1.16 | rooms.lua manifest | source/data/rooms.lua |
| v0.1.17 | continuity validator + Makefile hook | tools/canon/validate_continuity.sh |
| v0.1.18 | scene migration (canon lookup everywhere) | sweep source/scenes/* |
| v0.1.19 | playtest checklist | tools/playtest_checklist.md |
| v0.1.20 | hardware optimization pass + debug overlay | source/systems/debug_overlay.lua, Newb timer cleanup, etc |

After v0.1.20: any future content addition (new NPC, new scene, new object) MUST start by editing bible → re-run parser → re-generate manifests → validator passes → then write scene code that references canon. The backward-built workflow that produced v0.1.0-v0.1.10 stops here.

---

## What this preserves vs replaces

**Preserved as-is:**
- Noble Engine + LDtk + AnimatedSprite + GFXP stack
- Asset validator (1-bit + outline + silhouette dump) — adds a sibling, doesn't replace
- Progression.lua (runtime state) — gets `assert(canon.state_flags[name])` guards
- All canonical pinned assets
- Existing scene logic — wrapped in canon lookups, not rewritten

**Replaced:**
- Bare string ids scattered across LDtk + scene files → canon table lookups
- Implicit "newb has these animations" in Newb.lua init → declared in animations.lua + loaded
- Implicit "bedroom has these hotspots" in BedroomScene → declared in rooms.lua + iterated

**Added:**
- Bible-as-source-of-truth contract
- Per-build continuity validator gate
- Playtest walkthrough checklist
- Hardware perf audit

---

## Estimated ship cadence

Each step = 1-3h of focused work, single commit, single release tag bump. 10 steps total = ~2 full work days at the v0.1.X cadence. None of them break the running game; each ships its own `.pdx` zip to the release page.

If you want to skip the migration and keep building scene-by-scene, the v0.1.X chain continues as-is — but the canon-first workflow won't retroactively appear. The earlier you decide, the cheaper the migration; right now you have 10 scenes and ~20 ids to swap. Wait until you have 50 scenes and the swap becomes a week.
