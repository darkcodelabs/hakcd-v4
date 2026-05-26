# HAKCD Playtest Checklist

**Applies to:** v0.1.26+ (formally adopted — every release through v0.1.X until superseded)
**Authoring sprint:** Phase 13 / v0.1.26. Draft landed at v0.1.15 (`27305d6`); SceneRouter (Phase 11 `ba9aeab`) + Progression flag migration (Phase 12 `d0ad9ba`) verified against the transition + flag tables below.
**Source-of-truth:** `source/data/canon.lua` (ids), `source/data/continuity.lua` (transition map + flag rules), `source/data/animations.lua` (newb state machine), `source/sounds/manifest.lua` (music + SFX wiring).
**Build target:** Playdate hardware (rev A and rev B). Simulator is an acceptable smoke check but is NOT a substitute for hardware verification.

> Every test step has an **expected outcome**. If the actual behavior diverges, mark as **FAIL**, capture the screen + the line in `source/scenes/<SceneName>.lua` that fired, and add to `Known gaps / FOLLOWUP` at the bottom.

---

## 0. Pre-flight (do BEFORE walkthrough)

1. **Clean compile.**
   - `make clean && make all`
   - Expected: pdc exits 0. No warnings about missing imagetables / sounds / fonts.
2. **Sideload `.pdx`** via Settings ▸ Game ▸ Sideload (or USB upload).
   - Expected: HAKCD tile appears in Games. Launch sound + icon render.
3. **First-boot save-state safety.**
   - Delete prior save (`Settings ▸ Game ▸ HAKCD ▸ Reset Data`) OR use a fresh device.
   - Expected: launching HAKCD does NOT nil-deref. `Noble.GameData` initialises with defaults from canon (`tyson_unlock=false`, `pwnglove_mode_complete=false`, `coin_0_status='minted'`, `coin_1..2='available'`, `coin_3..23='locked'`).

---

## 1. Scene walkthrough — happy path

### 1.1 TitleScene

1. Boot game.
   - Expected: `images/title` renders full-frame on black background. "press any key" prompt blinks every 700 ms.
   - Music: `sounds/music/title_loop` starts on `:enter()` and loops forever.
2. Press **A**.
   - Expected: `Noble.transition(BedroomScene)`. Title music stops (path differs from `bedroom_loop`).
3. (Re-boot and try **B** at title.)
   - Expected: same advance behavior (both A and B route to `advance()` in `TitleScene.lua`).

### 1.2 BedroomScene (sc01)

1. After title transition.
   - Expected: `bedroom_loop` starts. LDtk `Bedroom` level renders Background + Foreground layers. Newb sprite spawns at `player_spawn` entity (or 200, 168 fallback).
   - 4 hotspot triggers active (invisible sprites with `hotspot_id` field): `computer`, `modem`, `phone`, `bed`.
2. Walk newb over **computer** hotspot.
   - Expected: bottom prompt bar shows `[A] USE COMPUTER` (label per `canon.objects.computer.label`).
3. Press **A** on computer.
   - Expected: `Noble.transition(ComputerScene)`. Music does NOT restart (bedroom_loop aliases through Computer/Modem/Phone in `sound_manifest.music_for_scene`).
4. Return to bedroom, walk to **modem**. **A**.
   - Expected: `Noble.transition(ModemScene)`. Music continuous.
5. Return, walk to **phone**. **A**.
   - Expected: `Noble.transition(PhoneScene)`. Music continuous.
6. Return, walk to **bed**. **A**.
   - Expected: `Noble.transition(PlaygroundScene)`. `bedroom_loop` STOPS; `playground_loop` starts.

### 1.3 ComputerScene (sc01 modal)

1. From bedroom, A on computer.
   - Expected: terminal background. `bbs_boot_sequence` dialogue plays (typewriter, 28 ms per char per `animations.system.terminal_typewriter`). 3 lines expected per `canon.dialogue_ids.bbs_boot_sequence.lines_count`.
2. Press **A** to advance pages.
3. Press **B**.
   - Expected: `Noble.transition(BedroomScene)`. Music continuous.

### 1.4 ModemScene (sc01 modal)

1. From bedroom, A on modem.
   - Expected: war-dialer interface renders. `modem_war_dialer` dialogue (14 lines per canon).
2. Press **A** to advance / **B** to abort.
   - Expected: both routes return to `BedroomScene`. Music continuous.

### 1.5 PhoneScene (sc01 modal)

1. From bedroom, A on phone.
   - Expected: phone UI renders. `mom_intro` dialogue plays (5 lines per canon, speaker = `mom`).
2. Press **A** to advance / **B** to hang up.
   - Expected: returns to `BedroomScene`. Music continuous.

### 1.6 PlaygroundScene (playground)

1. Arrive via `bed` hotspot in Bedroom OR via System Menu → `pwnglove mode`.
   - Expected: `playground_loop` music starts. LDtk `Playground` level renders. Newb spawns at `player_spawn` (or 200, 168 fallback). 9 hotspot triggers: `lockpick_station`, `tyson_cabinet`, `coin_vault`, `rfid_pedestal`, `payphone`, `ir_wall`, `gravity_arena`, `subghz_tuner`, `portal_pedestal`.
2. Walk to each placeholder hotspot (`rfid_pedestal`, `payphone`, `ir_wall`, `gravity_arena`, `subghz_tuner`, `portal_pedestal`), press **A**.
   - Expected: `[placeholder] <id>` toast for 2.2 s. No scene transition. No crash.
3. Walk to **lockpick_station**, **A**.
   - Expected: `Noble.transition(LockpickScene, ..., {return_scene = PlaygroundScene})`. `playground_loop` STOPS (LockpickScene maps to nil music).
4. Walk to **tyson_cabinet**, **A**.
   - Expected: `Noble.transition(TysonScene, ..., {return_scene = PlaygroundScene})`. `tyson_loop` starts.
5. Walk to **coin_vault**, **A**.
   - Expected: `Noble.transition(CoinVaultScene, ..., {return_scene = PlaygroundScene})`. `coinvault_loop` starts.

### 1.7 LockpickScene (playground minigame)

1. Entered with `return_scene = PlaygroundScene`.
   - Expected: silent (no music bed). 5-PIN STANDARD UI: top bar (PUZZLE / ATTEMPT n/3 / POINTS / timer / status pill), compass + binding-zone pill, lock body image, tension meter (STOP/CARE/SAFE), controls bar, dialog bar with newb portrait.
2. Crank rotates aim 0–359°.
   - Expected: compass needle tracks crank.
3. Press **A** with aim INSIDE binding zone (default 45–90°).
   - Expected: pin sets, `lockpick_pin_set` + `lockpick_pin_click_*` SFX fire, newb reaction dialog ("Easy. Standard pin.", etc.).
4. Press **A** OUTSIDE binding zone.
   - Expected: pin flashes (18-frame dot-3 dither), all pins reset, attempt count decrements, `lockpick_snap` SFX, dialog "Snapped. Try again."
5. Set all 5 pins.
   - Expected: state = `open`, "Clean. Knuckleheads style." dialog (3 s), `lockpick_open` SFX, 2.5 s hold, then `Noble.transition(PlaygroundScene)`.
6. Exhaust 3 attempts OR let timer hit 0:00 OR press **B**.
   - Expected: state = `failed`, dialog + delayed exit back to PlaygroundScene.

### 1.8 TysonScene (playground minigame)

1. Entered with `return_scene = PlaygroundScene`. Code = `007-373-5963`.
2. (First run, `tyson_unlock = false`.)
   - Expected: 11 slot grid renders. Cursor starts on first non-dash slot. `tyson_loop` music.
3. Crank.
   - Expected: every 36° step ticks `current_digit` 0..9 wrap. `tyson_digit_select` SFX per tick.
4. Press **A**.
   - Expected: commits digit to current slot, `tyson_digit_commit` SFX, cursor auto-skips dashes.
5. Enter the correct full code (`0`,`0`,`7`,`3`,`7`,`3`,`5`,`9`,`6`,`3`).
   - Expected: state = `unlocked`. `tyson_winner` SFX. "* TYSON MODE *" banner with dot-5 GFXP flicker every 4 frames for 3 s. `Progression.set_tyson_unlocked(true)` fires (writes `Noble.GameData.flags.tyson_unlock = true`). Auto-transition back to `PlaygroundScene`.
6. Press **B** during entry.
   - Expected: state = `failed`, ~600 ms hold, transition back.

### 1.9 CoinVaultScene (playground overlay)

1. Entered with `return_scene = PlaygroundScene`.
   - Expected: `coinvault_loop` music. 4x6 grid of 24 coin slots. Coin 0 shows minted art (`images/coins/coin_0`). Coins 1–3 show available art. Coins 4–23 show `images/coins/coin_locked`. Cursor on slot 1.
2. D-pad moves cursor.
   - Expected: `coin_navigate_tick` SFX per move. Dialog bar updates with `dialog.grid_highlight` from `coins.json` for the highlighted coin.
3. **A** on a coin (grid mode).
   - Expected: `coin_zoom_whoosh` SFX, `zoomed = true`, large coin renders, multi-line dialog (`closeup` → `linger` → `long_linger`) cycles every 3 s.
4. **A** again (zoomed mode).
   - Expected: advances dialog line manually if multi-line.
5. **B** in zoom.
   - Expected: returns to grid view.
6. **B** in grid.
   - Expected: `Noble.transition(PlaygroundScene)`.

---

## 2. Transition checks — exhaustive `Noble.transition` audit

Cross-reference against `continuity.scenes[].transitions_to`. Each row below MUST work both directions where the back-link exists.

| From | To | Trigger | Source line |
|---|---|---|---|
| TitleScene | BedroomScene | A or B | `TitleScene.lua:49` |
| BedroomScene | ComputerScene | A on computer hotspot | `BedroomScene.lua:163` |
| BedroomScene | ModemScene | A on modem hotspot | `BedroomScene.lua:165` |
| BedroomScene | PhoneScene | A on phone hotspot | `BedroomScene.lua:167` |
| BedroomScene | PlaygroundScene | A on bed hotspot | `BedroomScene.lua:161` |
| ComputerScene | BedroomScene | B | `ComputerScene.lua:121` |
| ModemScene | BedroomScene | A or B (final) | `ModemScene.lua:70,74` |
| PhoneScene | BedroomScene | A or B (final) | `PhoneScene.lua:44,52` |
| PlaygroundScene | LockpickScene | A on lockpick_station | `PlaygroundScene.lua:140` |
| PlaygroundScene | TysonScene | A on tyson_cabinet | `PlaygroundScene.lua:143` |
| PlaygroundScene | CoinVaultScene | A on coin_vault | `PlaygroundScene.lua:146` |
| LockpickScene | PlaygroundScene | win/fail/B (via return_scene) | `LockpickScene.lua:213` |
| TysonScene | PlaygroundScene | win/fail/B (via return_scene) | `TysonScene.lua:132` |
| CoinVaultScene | PlaygroundScene | B from grid (via return_scene) | `CoinVaultScene.lua:220` |
| (System menu) → PlaygroundScene | from any scene | `pwnglove mode` menu item | `main.lua:69` |
| (System menu) → checkpoint | from any scene | `back to story` menu item | `main.lua:62` |

**Orphan-transition check:** grep `Noble.transition` in `source/scenes/` — every target MUST be one of the 9 scene classes registered in `main.lua`. Any target not in `canon.scenes` is an orphan; flag as **FAIL**.

```sh
grep -nR "Noble.transition" source/scenes/ | grep -oE 'transition\([^,)]+' | sort -u
```

---

## 3. Dialogue checks — every canon dialogue id resolves

Per `canon.dialogue_ids`:

| id | speaker | trigger | scene | expected lines |
|---|---|---|---|---|
| `mom_intro` | mom | enter phone hotspot, A | PhoneScene | 5 |
| `bbs_boot_sequence` | system | enter computer hotspot, A | ComputerScene | 3 |
| `modem_war_dialer` | system | enter modem hotspot, A | ModemScene | 14 |
| `coin_zero_welcome` | newb | enter coin vault first time | CoinVaultScene | (cycles via coins.json[0].dialog) |
| `tyson_already` | system | enter TysonScene when `tyson_unlock==true` | TysonScene | "ALREADY GRANTED -- 1987" banner, 2.5 s, auto-exit |

**Method:**
1. For each row, perform the trigger and confirm the listed text body renders.
2. Confirm `repeatable` flag matches: per `continuity.dialogue_unlock_rules`, `coin_zero_welcome` is `repeatable=false` (verify it does not re-trigger after first view). All others `repeatable=true`.

---

## 4. Save / load validation

Persistence layer: `Noble.GameData` via `Progression.lua`. Flag table is keyed `flags.<flag_name>`.

1. **`tyson_unlock` persistence.**
   - Enter `007-373-5963` correctly in TysonScene. Confirm "TYSON MODE" banner.
   - Exit to Playground, then to Bedroom (System Menu → `back to story`).
   - Sideload `.pdx` again (or full device reboot).
   - Walk to `tyson_cabinet`, A.
   - Expected: TysonScene immediately enters `already_granted` branch, shows "ALREADY GRANTED -- 1987" banner for 2.5 s, auto-exits.

2. **`pwnglove_mode_complete` persistence.**
   - In PlaygroundScene, press A on all 9 hotspots at least once.
   - (Future: PlaygroundScene sets `pwnglove_mode_complete=true` on all-9 visit — currently NOT wired, see `Known gaps`.)
   - After wiring lands: sideload, expected flag = `true`.

3. **Coin state persistence.**
   - Coin 0 starts `minted` by default per `canon.state_flags.coin_0_status.default`.
   - Coins 1, 2 start `available`. Coins 3–23 start `locked`.
   - After any future state mutation (none currently wired), sideload and confirm grid art reflects persisted state.

4. **Save-corruption safety.**
   - Manually corrupt `Noble.GameData` (write garbage via dev menu, or delete save mid-session).
   - Expected: next boot does NOT crash; falls back to canon defaults.

---

## 5. Inventory progression

**Current state:** no inventory operations are wired in v0.1.15. Bible `continuity.inventory_requirements` table declares 13 future tool gates (War Dialer, Password Cracker, Red Box, Beige Box, Blue Box, Social Engineering, Lockpick) but none are equipped/consumed in any v0.1.X scene yet.

1. Confirm no scene attempts to read an inventory item.
   - Method: `grep -nR "inventory" source/scenes/ source/utilities/` should return zero gameplay reads in v0.1.15.
2. Placeholder test: enter every minigame and confirm no `required_tool` check fires (LockpickScene and TysonScene gate solely on hotspot proximity in the playground, not on possessing the tool).

---

## 6. Music continuity

Music routing is path-equality based in `sound_manifest.start_scene_music` — scenes that alias to the same path do NOT restart the track on transition.

| Scene | Music path | Behavior on enter |
|---|---|---|
| TitleScene | `sounds/music/title_loop` | starts |
| BedroomScene | `sounds/music/bedroom_loop` | starts |
| ComputerScene | `sounds/music/bedroom_loop` | CONTINUES (alias) |
| ModemScene | `sounds/music/bedroom_loop` | CONTINUES (alias) |
| PhoneScene | `sounds/music/bedroom_loop` | CONTINUES (alias) |
| PlaygroundScene | `sounds/music/playground_loop` | starts (stops bedroom_loop) |
| LockpickScene | `nil` | STOPS music (silent minigame) |
| TysonScene | `sounds/music/tyson_loop` | starts |
| CoinVaultScene | `sounds/music/coinvault_loop` | starts |

**Tests:**
1. Bedroom → Computer → Modem → Phone → Bedroom cycle: listen for ZERO audible restart of `bedroom_loop`. Track must remain continuous.
2. Playground → Lockpick: music cuts cleanly. No clipping / no overlap.
3. Playground → Tyson: `playground_loop` stops, `tyson_loop` starts. No overlap.
4. Tyson (win) → Playground: `tyson_loop` stops, `playground_loop` resumes (cold restart, this IS expected).
5. CoinVault → Playground (B): `coinvault_loop` stops, `playground_loop` resumes.
6. Volume: every fileplayer is set to 0.7 by `start_scene_music`. Confirm no track is louder than the rest.

---

## 7. Crash checks

1. **pdc clean compile.**
   - `make clean && make all`
   - Expected: 0 errors, 0 warnings.
2. **Sideload boot.**
   - Fresh sideload to hardware. Expected: title splash within ~2 s, no error overlay.
3. **System menu invocation.**
   - From every scene (Title / Bedroom / each modal / Playground / each minigame), open the system menu and select `pwnglove mode` then `back to story`.
   - Expected: each pair round-trips with no nil deref, no orphan-transition error.
4. **First-time save read.**
   - Reset save data. Boot. Walk into every scene that reads `Noble.GameData` (TysonScene, CoinVaultScene via Progression).
   - Expected: `pcall` guards in `get_flags()` / `Progression.coin_status()` catch missing keys and fall through to canon defaults. No `attempt to index nil` errors.
5. **Mid-game lock event.**
   - Lock the device (sleep) mid-scene. Wake.
   - Expected: scene resumes without nil deref. Music resumes if it was playing.
6. **Crank disconnect during TysonScene / LockpickScene.**
   - Dock crank mid-input.
   - Expected: cranked handler stops firing; scene does not crash. A/B still functional to commit/abort.

---

## 8. Hardware FPS checks

1. Set `Noble.showFPS = true` in `source/main.lua` (revert before commit).
2. Sideload. Walk through every scene.
3. Expected:
   - Steady 30 FPS in every scene (Noble runs at 30 by default for 1-bit games).
   - No drop below 28 FPS in any scene during normal play.
   - No GC spike >16 ms on scene transition. (Watch FPS counter during `Noble.transition`; it should not flicker to single digits.)
4. Specific stress checks:
   - **LockpickScene:** rapid crank + spam A on/off binding zone. FPS must hold 30.
   - **TysonScene:** spam crank + spam A. FPS must hold 30. GFXP dot-5 flicker on TYSON banner must run at 7.5 FPS (every 4 frames) without dragging update().
   - **CoinVaultScene:** spam d-pad to rapid-cursor. FPS must hold 30.
   - **PlaygroundScene + BedroomScene:** walk into and out of every hotspot rapidly. Hotspot overlap check + `[A] LABEL` toast must not allocate per frame.
5. Allocation audit (manual code review, not runtime):
   - No `gfx.image.new` inside any `:update()` method.
   - No `imagetable.new` outside `:init()` / `:enter()`.
   - Newb sprite reuses the same imagetable across scene transitions.

---

## 9. Per-version smoke (run after EVERY ship from v0.1.16 onward)

Quick 5-minute smoke. If ANY step fails, do not tag the release.

1. `make clean && make all` → 0 errors.
2. Sideload to hardware (preferred) or simulator (acceptable for non-audio changes only).
3. Title → A → bedroom. Music plays.
4. Visit all 4 bedroom hotspots. Each opens its scene. B returns to bedroom. Bedroom music continuous through all 3 modals.
5. Sleep on bed → Playground. Playground music starts.
6. Visit Lockpick (silent), Tyson (own music), CoinVault (own music). Each B returns to Playground.
7. System Menu → `pwnglove mode` from Bedroom. Lands in Playground.
8. System Menu → `back to story`. Returns to Bedroom (or whatever was checkpointed).
9. Confirm no error overlay, no audible audio glitch, no visible frame drop.

If you bumped `pdxinfo.version`, re-run **step 1 + 2** AFTER the bump (a stale build dir can mask broken pdc).

---

## 10. Failure case catalog — explicit known-bad inputs

These inputs MUST be handled gracefully (no crash, no soft-lock).

| Scene | Bad input | Expected behavior |
|---|---|---|
| TitleScene | press B | advances to BedroomScene (intentional — both buttons advance) |
| TitleScene | hold A repeatedly | single transition fires (Noble.transition guards re-entry) |
| BedroomScene | walk off-map | wall collision via `LDtk.get_empty_tileIDs('Solid')` blocks movement |
| BedroomScene | press A with no hotspot active | no-op |
| ComputerScene | hold A | advances dialog pages, does not skip transition |
| ComputerScene | press B before dialog finishes | returns to BedroomScene anyway |
| ModemScene | press B during animation | returns to BedroomScene |
| PhoneScene | press B mid-dialog | returns to BedroomScene |
| PlaygroundScene | press A on placeholder hotspot (rfid/payphone/ir/gravity/subghz/portal) | toast `[placeholder] <id>` for 2.2 s, no transition |
| LockpickScene | A outside binding zone | snap, attempt-- ; on 0 attempts → fail → return |
| LockpickScene | over-tension (rapid A spam, tension hits 1.0) | "Easy. Easy. Don't snap it." dialog, attempt--, pins reset |
| LockpickScene | timer expires (60 s default) | "Time up. Snapped the wrench." → fail → return |
| LockpickScene | B mid-game | "Abandoned." dialog, 800 ms hold, return |
| LockpickScene | crank dock mid-game | aim freezes at last value, scene continues |
| TysonScene | wrong code at slot 11 (e.g. `007-373-5962`) | state = `failed`, slots reset to `?`, "That's not it. Try again.", 2.2 s hold, auto-exit |
| TysonScene | B mid-entry | state = `failed`, 600 ms hold, return |
| TysonScene | enter scene when `tyson_unlock==true` already | enters `already_granted` branch immediately, 2.5 s banner, auto-exit. Does NOT prompt for code again. |
| TysonScene | crank dock mid-entry | digit selection stops, A still commits whatever's shown |
| CoinVaultScene | d-pad past grid edge (cursor < 1 or > 24) | move ignored, cursor clamps |
| CoinVaultScene | A on locked coin | zoom into closeup view shows `images/coins/coin_locked` art, "Locked. Phrase not yet discovered." dialog. No crash. |
| CoinVaultScene | corrupted coins.json | falls back to `coin 0 minted, coins 1-2 available, rest locked` defaults |
| any scene | sideload while running | not applicable (sideload kills current process) |
| any scene | low battery shutdown mid-save-write | next boot falls back to defaults; no half-written `Noble.GameData` |

---

## Known gaps / FOLLOWUP (Phase 14 hardware audit)

The items below are **intentionally not blocking** for v0.1.15 / v0.1.23 — Phase 14 will run a full hardware audit and convert each into either a pass or a ticket.

- **`pwnglove_mode_complete` flag.** Declared in canon, but PlaygroundScene does NOT currently track all-9-station-visited state. Wire-up landing in v0.1.18+ scene migration pass.
- **`current_act` progression.** Default = 1; no scene currently advances it. Placeholder until bible scenes SC02-SC26 wire in.
- **Coin unlock progression.** Coins 1-2 are `available` per defaults but no phrase-puzzle exists to flip them `minted`. Coins 3-23 stay `locked`. Awaits per-coin phrase puzzle ship.
- **Dialogue text bodies.** Counts match canon (`mom_intro=5`, `bbs_boot_sequence=3`, `modem_war_dialer=14`) but verbatim text vs bible has not been line-by-line diffed. Add to Phase 14.
- **LDtk `player_spawn` validation.** Both Bedroom and Playground fall back to `(200, 160)` / `(200, 168)` if LDtk entity is missing. Validator should fail build if either level lacks `player_spawn`. Adds in Phase 7 validator (already shipped v0.1.17).
- **Music volume normalization.** All tracks set to 0.7 in `start_scene_music`, but per-track loudness has not been measured. Phase 14: run LUFS sweep and document offsets.
- **Crank dock handling on TysonScene/LockpickScene.** Current behavior is "input stops"; a docked-crank prompt overlay would be friendlier.
- **System menu `pwnglove mode` checkpoint stack.** `_scene_checkpoint` is single-slot (not a true stack). Round-tripping pwnglove from Playground itself loses the prior checkpoint. Edge case, low priority.
- **Hardware FPS audit on rev A vs rev B.** All FPS claims above are simulator-derived. Phase 14 to capture real-device FPS logs per scene.
- **GFX dither pattern memory.** `gfxp.set(...)` is called frequently in LockpickScene and TysonScene draws; confirm no per-frame allocation.
- **Save-data version field.** `Noble.GameData` does not currently embed a schema version. Migration of saves across canon changes is fragile. Phase 14: add `save_version` key + migration hook.

---

## Sign-off

| Field | Value |
|---|---|
| Version tested | v0.1.X |
| Hardware rev | (rev A / rev B / simulator) |
| Tester | |
| Date | |
| Pass / Fail | |
| Failures captured | (link to FOLLOWUP entries or new tickets) |
