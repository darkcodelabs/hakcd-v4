# Hardware Performance Audit — hakcd-v4 v0.1.15 snapshot

Audit captured pre-Phase 14. Phase 14 v0.1.24 will land actual perf fixes
against these findings. This document is NOTES ONLY — no code was changed
during the audit. Treat it as the gate checklist the Phase 14 PR must
satisfy before tagging v0.1.24.

Conventions used below:
- **PASS** — pattern is fine as-is on hardware.
- **WARN** — works but should be cleaned up before ship.
- **FAIL** — must be fixed in Phase 14 before tagging.

Hardware target: physical Playdate (rev A/B), 30 FPS steady, ~16 MB Lua heap
budget. Simulator readings are NOT authoritative for this audit — every
finding must be re-validated on device during Phase 14.

---

## Per-scene findings

### TitleScene
- **Allocations in update()**: PASS. `drawBackground` runs each frame but
  only reads timestamps and reuses cached `self._title_img`. No allocations.
- **Timer cleanup in exit()**: PASS. No `playdate.timer.new` /
  `frameTimer.new` usage — blink is computed off `getCurrentTimeMilliseconds`,
  so there is nothing to clean up.
- **Asset loads in enter() not init()**: PASS. `gfx.image.new("images/title")`
  lives in `scene:init()`, the correct Noble lifecycle slot.
- **Sprite count estimate**: 0 sprites added — scene draws everything via
  `drawBackground`.
- **Collide rect simplicity**: N/A (no collision sprites).
- **Draw-call density**: 1 image draw + 1 conditional `drawTextAligned` per
  frame. Cheap. The `// BLINK_MS` math runs every frame but is integer-only.
- **Music player lifecycle**: PASS via `sound_manifest.start_scene_music`
  shared fileplayer. Scene does NOT call `stop` in exit, but the manifest
  compares paths on next `start_scene_music` so the title loop is correctly
  swapped on transition. WARN: `exit()` is not defined, so the manifest's
  current track stays alive across an unexpected transition path (e.g. menu
  back to title) — verify on hardware.

### BedroomScene
- **Allocations in update()**: PASS. `update()` does `overlappingSprites()`
  (returns a fresh table each call — see Cross-cutting note) and integer
  comparisons. No image/imagetable/sprite allocations per frame.
- **Timer cleanup in exit()**: PASS. No SDK timers started.
- **Asset loads in enter() not init()**: **FAIL**. Every `enter()` call
  re-walks the LDtk level: `LDtk.get_layers` → `LDtk.create_tilemap` for
  every tile layer → `gfx.sprite.new` per layer → `addWallSprites` per layer
  → entity iteration. The LDtk JSON itself is loaded once (sentinel
  `_hakcd_ldtk_loaded`), but tilemap + wall-sprite construction repeats per
  enter. This will spike memory each time the player re-enters from a modal
  (Computer / Modem / Phone / Playground → Bedroom). Move tilemap creation
  into `init()` and re-attach sprites on enter.
- **Sprite count estimate**: ~3 layer sprites + Newb + N hotspot sprites
  (currently 4: bed, computer, modem, phone) + wall sprites from
  `addWallSprites` (one per solid tile). On a 25x15 room with ~40% solid
  fill that's ~150 wall sprites. **WARN** > 50 — Phase 14 should investigate
  whether `addEmptyCollisionSprites` or a single combined tilemap-collision
  rect would be cheaper.
- **Collide rect simplicity**: PASS — all `setCollideRect` calls are single
  rectangles.
- **Draw-call density**: `drawForeground` does 2 `fillRect` + 2 `drawText`
  conditionally (only when hotspot active or dialog visible). PASS.
- **Music player lifecycle**: PASS via manifest. Bedroom_loop is shared with
  Computer/Modem/Phone modal scenes by path comparison so re-entry is a
  no-op. `exit()` not defined — relies on next scene's `start_scene_music`
  to stop or keep. PASS for current scene graph.

### PlaygroundScene
- **Allocations in update()**: PASS. Same pattern as BedroomScene.
- **Timer cleanup in exit()**: PASS. No SDK timers.
- **Asset loads in enter() not init()**: **FAIL**. Identical pattern to
  BedroomScene — tilemap rebuilt every enter. Critical since LockpickScene /
  TysonScene / CoinVaultScene all return here.
- **Sprite count estimate**: Same as Bedroom (~150 wall sprites + 3 hotspots
  + Newb + 2-3 layer sprites). **WARN**.
- **Collide rect simplicity**: PASS.
- **Draw-call density**: PASS, same as Bedroom.
- **Music player lifecycle**: PASS via manifest.

### LockpickScene
- **Allocations in update()**: PASS in `update()`. Per-frame work is
  tension decay + pin failure_flash decrement + 1 `getCurrentTimeMilliseconds`
  read. **WARN in drawBackground**: many `string.format` calls per frame
  (time format, attempt format, points pill, binding zone text). Each
  `string.format` allocates a new Lua string and contributes to GC churn.
  Pre-format on state change and cache.
- **Timer cleanup in exit()**: PASS. No SDK timers — everything uses
  `_exit_at_ms` deadline checks against `getCurrentTimeMilliseconds`.
- **Asset loads in enter() not init()**: PASS. `_lock_img` and `_newb_img`
  load in `init()`.
- **Sprite count estimate**: 0 — pure draw-based scene.
- **Collide rect simplicity**: N/A.
- **Draw-call density**: **WARN**. Every frame redraws: top bar (3 box
  rects + 2 text + 1 pill + hourglass + time text + result pill), mid band
  (compass with `cos`/`sin`/`fillTriangle`, binding pill, lock image, 5x pin
  drawing with GFXP set/unset, unlock zone line + text), tension meter (3
  `fillRect` with GFXP swaps + 3 zone labels + marker triangle), controls
  bar (1 box + 3 text), dialog bar (1 box + text + rect + portrait or
  fallback text). Estimate ~35-45 draw calls/frame. Phase 14: cache the
  static top-bar + controls-bar + dialog-bar frame into one offscreen image
  once per state change; only redraw the compass / tension / pin layer.
- **Music player lifecycle**: PASS. Scene is intentionally silent; manifest
  returns `nil` for `LockpickScene` and `start_scene_music` stops any
  current player.

### TysonScene
- **Allocations in update()**: PASS in `update()` itself (just deadline
  checks). **WARN in drawBackground**: 11 `gfx.drawTextAligned(tostring(ch))`
  + 11 `gfx.drawRect` per frame. `tostring` on `self.current_digit` also
  allocates each frame. Same GFXP `set('gray-3')` / `set('white')` swap
  inside the slot loop happens up to 11 times — pattern set is a global
  state poke, not free.
- **Timer cleanup in exit()**: PASS. No SDK timers.
- **Asset loads in enter() not init()**: PASS — no asset loads, scene is
  pure-draw.
- **Sprite count estimate**: 0.
- **Collide rect simplicity**: N/A.
- **Draw-call density**: **WARN**. ~25-30 draw calls/frame plus the
  flicker overlay during 'unlocked' (extra full-screen `fillRect` + GFXP
  set). Phase 14: pre-render the empty slot grid background once on state
  change; only the current cursor digit + overlay needs per-frame redraw.
- **Music player lifecycle**: PASS via manifest (`tyson_loop`).

### CoinVaultScene
- **Allocations in update()**: PASS. `update()` only advances dialog index
  on a timestamp deadline. No allocations.
- **Timer cleanup in exit()**: PASS. No SDK timers.
- **Asset loads in enter() not init()**: **FAIL**. `enter()` loads
  `coins.json` from disk (file open + chunked read + json.decode + table
  build) AND loads 9 images (`coin_locked`, `coin_0..3`, `coin_0..3_large`,
  `portraits/newb`) on every enter. CoinVault is reachable from
  PlaygroundScene and returns to it — each round-trip re-reads the JSON and
  reloads all coin images. The `exit()` defensively nils `self.coin_imgs`
  but the loader doesn't memoize. Move to `init()` and keep references; let
  Lua GC release them on scene destroy.
- **Sprite count estimate**: 0 — grid drawn each frame as primitives.
- **Collide rect simplicity**: N/A.
- **Draw-call density**: **FAIL**. Grid mode draws 24 cells per frame; each
  cell is a `drawRoundRect` + `drawText(id)` + image `drawScaled` +
  `drawTextAligned` status label. That's ~96 draw calls just for the grid,
  plus sidebar (~15 calls) and dialog bar (~8 calls). 24 image
  `drawScaled` calls every frame with per-call scale-factor math is
  expensive. Phase 14: pre-render the entire grid into one offscreen
  `playdate.graphics.image` on cursor change, then a single image draw +
  cursor highlight overlay. This is the single biggest perf win available.
- **Music player lifecycle**: PASS via manifest (`coinvault_loop`).

### ComputerScene
- **Allocations in update()**: PASS. `update()` does timestamp math and
  integer comparisons. **WARN**: `_pageTotalChars` runs an `ipairs` walk +
  `#line` strlen on every page advance (rare, not per-frame, so OK).
- **Timer cleanup in exit()**: PASS. No SDK timers.
- **Asset loads in enter() not init()**: PASS — no assets.
- **Sprite count estimate**: 0.
- **Collide rect simplicity**: N/A.
- **Draw-call density**: **WARN**. `drawForeground` walks all lines and
  calls `line:sub(1, remaining)` per visible line per frame — that
  allocates a new string each call. Status strip adds `fillRect` +
  `drawText` per frame. Phase 14: cache the rendered page-up-to-charCount
  into an offscreen image; only redraw when `charCount` advances.
- **Music player lifecycle**: PASS (aliases `bedroom_loop`, manifest
  no-ops re-entry).

### ModemScene
- **Allocations in update()**: PASS. **WARN**: `table.insert(self.shown,
  s.txt)` runs each step transition — those are infrequent (14 steps over
  ~10s) so it's fine.
- **Timer cleanup in exit()**: PASS.
- **Asset loads in enter() not init()**: PASS — no assets.
- **Sprite count estimate**: 0.
- **Collide rect simplicity**: N/A.
- **Draw-call density**: WARN. `drawForeground` walks up to 12 visible
  shown lines, each a `drawText` call + the status strip. ~15
  drawcalls/frame. Acceptable but cacheable.
- **Music player lifecycle**: PASS (aliases `bedroom_loop`).

### PhoneScene
- **Allocations in update()**: PASS.
- **Timer cleanup in exit()**: PASS.
- **Asset loads in enter() not init()**: PASS — no assets.
- **Sprite count estimate**: 0.
- **Collide rect simplicity**: N/A.
- **Draw-call density**: **WARN**. `drawForeground` runs every frame: 3
  `fillRect` + 3 `drawRect` + 5 `drawText` + 1 `drawTextInRect` + 1
  `string.format` — entire UI re-rendered each tick. Static frame +
  current line could be split: frame baked into one offscreen image, line
  text drawn on top.
- **Music player lifecycle**: PASS (aliases `bedroom_loop`).

### SpriteTestScene
- **Allocations in update()**: PASS.
- **Timer cleanup in exit()**: PASS — `newb:remove()` + nil-out is correct.
- **Asset loads in enter() not init()**: WARN. `Newb(200, 120)` constructor
  loads the imagetable every enter. Acceptable for a dev-only scene.
- **Sprite count estimate**: 1 (just Newb).
- **Collide rect simplicity**: PASS.
- **Draw-call density**: PASS (1 text label).
- **Music player lifecycle**: N/A — scene doesn't call manifest. WARN:
  any music started by a previous scene will keep playing. Add a
  `sound_manifest.start_scene_music(nil)` to silence cleanly.

---

## Cross-cutting findings

1. **Sprite class allocations / Newb sprite imagetable reload.** Newb's
   `init` re-loads `images/newb-table-32-32` every time a scene instantiates
   it. Bedroom + Playground each create a new Newb on every `enter()`.
   Phase 14: introduce a single shared imagetable cached in a global
   (e.g. `_G._newb_imagetable`) and pass it to Newb instances, OR pool a
   single Newb sprite across scenes and `:moveTo` on enter.

2. **`overlappingSprites()` allocates per frame.** Both Bedroom and
   Playground call `self.newb:overlappingSprites()` every update tick.
   The SDK returns a fresh Lua table each call. With ~5 hotspots + walls
   nearby this is small, but it's pure GC churn — Phase 14 should consider
   `playdate.graphics.sprite.querySpriteInfoAlongLine` or cache the
   hotspot list and do manual rect-intersection math (5 cheap comparisons
   per frame, zero allocations).

3. **LDtk world.ldtk load timing.** `LDtk.load('levels/world.ldtk')` is
   correctly gated by `_G._hakcd_ldtk_loaded` sentinel — JSON parsed once.
   GOOD. However `create_tilemap` + `addWallSprites` + entity iteration
   still runs per scene enter. See per-scene FAIL above.

4. **Noble.GameData save flush cadence.** `Progression._save_state` calls
   `Noble.GameData.set('state', s, true)` — third arg = save immediately
   on every coin mint / item add / scene complete / act advance. Each
   call serializes the whole `state` table to disk. Acceptable cadence
   for the current scene set (saves are rare), but DO NOT call this from
   inside update() in any new scene. Add a doc-comment to Progression to
   make that contract explicit. WARN — Phase 14 should consider deferring
   to next-frame and coalescing.

5. **Sound manifest fileplayer reuse.** `sound_manifest.start_scene_music`
   correctly compares by path and reuses the running fileplayer when the
   next scene maps to the same track — this is the right design. Verify
   on hardware that `:isPlaying()` doesn't return false during the brief
   transition window between scenes. The shared `_currentMusic` fileplayer
   is never explicitly stopped before the game pauses; `gameWillPause` hook
   should pause it.

6. **SFX `sampleplayer.new` per play.** `M.play_sfx` does
   `playdate.sound.sampleplayer.new(target)` on every call. That re-opens
   the audio file each shot. **FAIL** — Phase 14: pre-load each SFX into a
   sampleplayer once at boot and call `:play(1)` on the cached instance.
   For variant lists (`step`, `lockpick_pin_click`) pre-load all variants
   and pick from the cache.

7. **GFXP `set('white')` to reset.** Multiple scenes call
   `gfxp.set('white')` after `gfxp.set('gray-3')` etc. Worth confirming
   that `'white'` actually resets to solid fill versus a white dither —
   Phase 14 should add a `gfxp.reset()` helper or document the convention
   in `gfxp` docs.

8. **String.format / tostring in draw loops.** LockpickScene, TysonScene,
   CoinVaultScene, ModemScene, PhoneScene all run `string.format` or
   `tostring` inside per-frame draw paths. Each call allocates a Lua
   string. Cache formatted strings on state-change instead.

---

## Per-Phase-14 fix list

In priority order:

1. **CoinVaultScene: bake grid to offscreen image.** Replace 24-cell
   per-frame redraw with single image draw + cursor overlay. Re-bake when
   any coin status changes (mint, unlock). _Effort: M (4-6h)._ Biggest
   single perf win.

2. **CoinVaultScene: move asset loads + coins.json read to `init()`.**
   Today every enter re-reads JSON + reloads 9 images. _Effort: S (1h)._

3. **BedroomScene + PlaygroundScene: move tilemap + wall-sprite construction
   into `init()`.** Today every enter rebuilds the entire collision world.
   _Effort: M (3-4h)._ Big win for re-entry from modal scenes.

4. **SFX cache: pre-load every `sound_manifest.sfx_paths` entry into a
   reusable sampleplayer at boot.** Replace `sampleplayer.new` per-shot
   with `:play(1)` on cached instances. _Effort: S (2h)._ Removes audio
   file-open latency, eliminates GC pressure from SFX bursts.

5. **Newb sprite: share one imagetable globally; pool one sprite across
   scenes.** Stop reloading `newb-table-32-32` on every scene enter.
   _Effort: S (2h)._

6. **Replace `overlappingSprites()` with manual rect-intersect for hotspot
   detection in Bedroom + Playground.** Zero-allocation per-frame.
   _Effort: S (1-2h)._

7. **LockpickScene: cache static chrome (top bar + controls bar + dialog
   frame) into offscreen image.** Only compass + tension meter + pin layer
   redraws per frame. _Effort: M (3h)._

8. **TysonScene: bake empty slot grid; redraw cursor + committed digits
   only.** _Effort: S (2h)._

9. **All scenes: pre-format strings that only change on state-transition.**
   `attempts_left` text, `time_left` text (1Hz update OK), `points` pill,
   `MINTED N/24`, slot digit `tostring`. _Effort: S (1-2h)._

10. **`PhoneScene` + `ComputerScene` + `ModemScene`: split static frame
    chrome from dynamic text into offscreen-image + per-frame text layer.**
    _Effort: M (2-3h)._

11. **Progression: add `_save_state_deferred` that coalesces dirty flag and
    flushes on next-frame.** Reduce disk I/O spike from rapid coin mints.
    _Effort: M (3h)._

12. **`gameWillPause` hook: pause `sound_manifest._currentMusic`. On
    `gameWillResume`: resume it.** Today the music keeps state across pause
    but the manifest doesn't explicitly handle it. _Effort: S (1h)._

13. **Add `exit()` to TitleScene + SpriteTestScene that calls
    `sound_manifest.start_scene_music(nil)` for cleanliness when
    transitioned-from in unexpected paths.** _Effort: S (30m)._

---

## Debug overlay design

Phase 14 MUST add a debug overlay toggle. Design:

- **Trigger**: system menu item `'debug overlay'` registered alongside the
  existing `'pwnglove mode'` / `'back to story'` items in `main.lua`. Menu
  item toggles a module-local boolean and persists it under
  `Noble.GameData.set('debug_overlay', bool)` so it survives device sleep.
  Secondary trigger for hardware-only QA: `down + B + crank-dock` combo
  detected in `playdate.update` (read via `playdate.buttonIsPressed`) —
  three-finger salute to avoid accidental toggle.
- **Renders** (top-right, 100x60 black-filled rect with 1px white border,
  drawn LAST after Noble's transition canvas so it floats on top):
  - Line 1: `FPS: NN` from a 30-frame rolling average of `1000/dt`.
  - Line 2: `SPR: NNN` from `#playdate.graphics.sprite.getAllSprites()`.
  - Line 3: `SCN: ClassName` from `Noble.currentScene().className` (or
    metatable name fallback).
  - Line 4: `NWB: idle_south` — Newb's current state via
    `Newb.currentState.name` if a Newb instance is on the scene graph.
  - Line 5: `MEM: NNNKB` from `collectgarbage('count')` (returns Lua-heap
    kilobytes — only Lua memory, not C/sprite memory, but it's what we
    have). Refresh once per 30 frames so it doesn't itself thrash.
- **Position**: x=296 y=2 size 100x60 (4-pixel right margin, 2-pixel top
  margin, doesn't overlap the standard Playdate sleep-clock area).
- **Toggleable**: stays OFF in release builds (`pdxinfo` `release=true`
  flag OR a compile-time `_RELEASE` global wired through `Makefile`). ON
  by default in `make dev` builds.
- Implementation lives in `source/utilities/DebugOverlay.lua` — single
  module with `DebugOverlay.toggle()`, `DebugOverlay.isOn()`,
  `DebugOverlay.draw()`. Called from a new `playdate.update` override or
  monkey-patched after Noble's update via a hook.
- Add to `source/main.lua`:
  ```lua
  if DebugOverlay and DebugOverlay.isOn() then DebugOverlay.draw() end
  ```
  inside or right after Noble's draw cycle. Order matters — must draw
  after Noble's `transitionCanvas:drawIgnoringOffset` and after
  `playdate.drawFPS` so it always sits on top.

---

## Targets

- **30 FPS steady** on hardware Playdate (not simulator). Measure with the
  debug overlay across a 60-second hands-on run that touches every scene
  and at least one round-trip through each modal.
- **No GC pause > 16ms** during transition. Measure by recording
  `collectgarbage('count')` before and after `Noble.transition`. If a
  scene's enter spikes the heap by > 2 MB the audit considers it a FAIL.
- **No allocation spike > 2 MB** during enter(). Hardest hitter is
  expected to be Bedroom/Playground tilemap rebuild — once fixed (#3
  above) this should hold.
- **All scenes `pdc`-compile clean.** Zero warnings from the Playdate
  compiler. CI gate before tagging v0.1.24.
- **No `sampleplayer.new` after boot.** Verify by grep — only
  `sound_manifest` initialisation should call `sampleplayer.new` once per
  SFX path.
- **Cold-boot to TitleScene `drawBackground`** under 1500ms on hardware.

---

## Methodology

How to run perf checks on simulator:

1. `make build` to produce `build/hakcd.pdx`.
2. Open the Playdate Simulator from `pdc`'s installed location and load
   the `.pdx`.
3. Enable `Devices > Show FPS` in the simulator menu — or set
   `Noble.showFPS = true` in `main.lua` for a build (DO NOT commit).
4. Use the simulator's `Devices > Show Allocations` panel to watch
   sprite + image allocations across scene transitions. Watch for
   monotonic growth (= leak).
5. Use `Devices > Print` to enable Lua print output. Add temporary
   `print(collectgarbage('count'))` instrumentation in `scene:enter` and
   `scene:exit` to bracket heap usage per transition.

How to enable Noble.showFPS:

- Edit `source/main.lua` line 32: `Noble.showFPS = true`. Rebuild.
  REVERT before commit. Noble draws the SDK FPS counter top-left.

How to read `playdate.getStats()` if Noble exposes it:

- Noble does NOT wrap `playdate.getStats()`. Phase 14 should add a thin
  wrapper in `source/utilities/Perf.lua` that calls
  `playdate.getStats()` once per second and exposes the result table
  (`drawTime`, `kernelTime`, `serviceTime`, `gameTime`, `GCTime`,
  `audioTime`, `idleTime`). The debug overlay should add a second column
  rendering these once it lands.
- `playdate.getStats()` is documented as zero-cost-when-disabled — must
  be enabled via `playdate.setStatsInterval(seconds)` first. Default off.

Sideload test order (run on hardware in this order, capturing FPS reading
at every step):

1. Cold boot → TitleScene. Note boot-to-prompt latency.
2. A → BedroomScene. Note transition time. Note FPS during idle.
3. Walk Newb around the room for 10 seconds. Note FPS during walk + step
   SFX bursts.
4. Walk to `computer` hotspot, A → ComputerScene. Page through all 3
   pages with A. B → BedroomScene. Note re-entry transition cost.
5. Walk to `modem` hotspot, A → ModemScene. Let the dial animation run
   to completion. B → BedroomScene.
6. Walk to `phone` hotspot, A → PhoneScene. Tap A through all 5 lines.
   Auto-returns to BedroomScene.
7. Walk to `bed`, A → PlaygroundScene. Note transition cost.
8. Walk to `lockpick_station`, A → LockpickScene. Pick the lock to win
   (or B-abandon). Note FPS during compass animation + tension changes.
   Returns to PlaygroundScene.
9. Walk to `tyson_cabinet`, A → TysonScene. Crank in 007-373-5963 (or
   B-cancel). Note FPS during 11-slot redraw.
10. Walk to `coin_vault`, A → CoinVaultScene. Navigate the full 4x6 grid
    (24 D-pad presses). A to zoom on coin 0. B to grid. B to playground.
    **Specific check**: does FPS dip during grid navigation? This is
    where the per-frame redraw cost will bite first.
11. System menu → `pwnglove mode` → PlaygroundScene direct jump. Then
    `back to story` → returns to checkpointed scene.
12. Sleep + wake the device. Verify scene state + music resume cleanly.

Capture for each step: FPS reading, transition wall-clock estimate
(by stopwatch is fine for a first pass), any visible stutter or audio
glitch. Report into Phase 14 ticket as a single comment.
