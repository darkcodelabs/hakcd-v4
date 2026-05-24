# PWNGLOVE MODE — Complete Reference

A deep-dive on what PWNGLOVE MODE is, why it exists, how it works, and how every piece connects. This is the canonical reference for the showcase / regression / demo-video mode in HAKCD.

---

## 1. What is PWNGLOVE?

PWNGLOVE is the in-game name for a real-world artifact built by Cory Kennedy — the project owner — and documented in **MagPi Issue 33 (May 2015)**. The firmware for it lives publicly at [`NoDataFound/TriKC0x01`](https://github.com/NoDataFound/TriKC0x01) (the file `PwnGlove.ino` is the canonical source of truth for the device's hardware behavior).

### The real device

- Original **Nintendo Power Glove peripheral**, gutted to the empty plastic shell
- **Raspberry Pi** inside the palm housing (runs RetroPie for game emulation)
- **Arduino** driving the sensor I/O
- **Four bend sensors** (thumb, index, middle, ring) wired to analog pin 3 via an **analog multiplexer** — the mux cycles all four through a single ADC channel
- **3-axis accelerometer** on analog pins 0/1/2
- **Bluetooth** dongle for Pi-to-host comms
- **Adafruit NeoPixel WS2812 array** (16×16 = 256 LEDs) driven from pin 6 via the FastLED library with palette swaps every 5 seconds
- **Modified wrist pad** — most original Power Glove buttons still work; some PCB was cut away to make room for the Arduino
- **Wrist-mounted display** for solo play
- **Wii Remote** support for two-player co-op (see `attachwii.sh` + `TriKCwii.py` in the same repo)
- **Konami code** input (`UUDDLRLRBA-Start`) unlocks "30 extra lives" mode — this is real, not lore

### Why it matters for HAKCD

HAKCD is a 1998 phreaker / hacker narrative. PWNGLOVE-the-game-item is grounded in PWNGLOVE-the-real-device. The fictional universe is anchored in the creator's actual work. That grounding is a deliberate design pitch — see `phase5_pwnglove_multitool_addendum.md` in the legacy 23studios repo for the original spec.

---

## 2. What is PWNGLOVE MODE?

PWNGLOVE MODE is a **sandbox playground scene** that lives outside the main story progression. The player can drop into it at any time via the **Playdate hardware system menu** (the menu button on the right side of the device), explore every PWNGLOVE capability on demand, then drop back into the story exactly where they left off.

It serves three purposes:

1. **Demo video setup.** Walking in, triggering each station, hearing the sound design, watching the NeoPixel HUD respond — fits a 90-second video. The narrative game itself requires playing through three acts; that doesn't fit a demo cut.
2. **Regression test.** If every capability works in the playground, the platform works. If something breaks in a story scene, you can reproduce it in the playground without replaying through hours of narrative to reach the broken state.
3. **Showcase / sandbox.** All four PWNGLOVE power layers and the Tyson master unlock are fully active in the playground regardless of story progress. Intentional — the playground showcases capability, doesn't gate it.

---

## 3. How to access it

System menu integration in `source/main.lua` adds two custom items via `playdate.getSystemMenu():addMenuItem(...)`:

| Menu item | Action |
|---|---|
| **pwnglove mode** | Snapshots current story state via `save_state.push_checkpoint("pre_pwnglove_mode")`, plays the 1.5-second glove intro splash, transitions to `PlaygroundScene` |
| **back to story** | Restores the snapshot via `save_state.restore_checkpoint("pre_pwnglove_mode")`, returns to the previous scene (or TitleScene as a fallback) |

The checkpoint is a deep-copy of all save_state flags (story progress, inventory, completed_scenes, etc.). Audio prefs (music_enabled, music_volume, sfx_volume) are intentionally NOT checkpointed so volume changes made in the playground persist back into the story.

In `hakcd-v4`, this menu wiring is in the Port commit (`378f81c`) at `source/main.lua`.

---

## 4. The four power layers

PWNGLOVE has four progressive power layers in the canonical story, all of which are fully unlocked in the playground:

### Layer 1 — Konami buffer

Equip-unlocked the moment PWNGLOVE is acquired. No story gate.

- Input the Konami code `Up Up Down Down Left Right Left Right B A Start` on any scene with PWNGLOVE equipped
- Arms a **+30 extra attempts buffer** on the next minigame
- Crank past the +30 floor pushes the buffer higher on a logarithmic curve: `attempts = 30 + log(1 + crank_revs_post_konami) * 25`
  - 1 rev = 30, 10 revs = 60, 100 revs = 85, asymptote at 100

### Layer 2 — Flipper Zero capability suite

Six tools, each unlocked by a specific story beat in narrative mode, all unlocked in playground:

| Tool | Function | Story unlock | Period-accurate? |
|---|---|---|---|
| **RFID Clone** | Read badge → store → emit clone | Parking Garage scene (Act 2) | Yes — 1998 RFID common |
| **Sub-GHz Replay** | Capture cordless / garage door / pager → replay | Mrs. Kowalski's garage (Act 2) | Yes |
| **IR Learn/Replay** | TV-B-Gone — kill CRTs, unlock IR-locked doors | Corporate BBS (Act 3) | Yes |
| **iButton Emulate** | Read 1-Wire iButton key → emulate at locked door | Office break-in (Act 3) | Yes — Dallas Semi iButton 90s |
| **Blue Box Tones** | Generate 2600Hz + DTMF for phreak ops | Bell pedestal (Act 1) | Yes — canonical phreaker tool |
| **Bad USB Script** | HID injection at unattended workstations | Aegis Corp datacenter (Act 4) | Slight anachronism — earned per Konami precedent |

D-pad up/down cycles the active tool. A activates it on a hotspot target.

### Layer 3 — Portal gun

Acquired in Act 3 after the Phractal Kingdom scene. Narrative: "The glove caches BBS modem handshakes — re-dialing a cracked system is faster than physical traversal."

- **Hold B + crank** to charge `portal_energy` 0..100
- Energy thresholds gate destinations:
  - 0–25: scenes in current act only
  - 25–60: any visited scene in same OR previous act
  - 60–100: any visited scene incl. SecKC hive
- Release B with energy ≥ 25 = warp
- Release B with energy < 25 = portal collapse + **the use is consumed anyway** (commitment risk)
- Cooldown: 1 use per act, refills on act transition
- **Story-locked destinations** (`sc_aegis_datacenter`, `sc_seckc_hive`) show `[LOCKED-STORY]` and can't be warped to — only walked

### Layer 4 — Gravity gun

Acquired in Act 4 from the Aegis crank room. Narrative: "PWNGLOVE's NeoPixel array doubles as an EMF coil resonator — manipulates small metal objects within 2 meters."

- A on a movable object attaches it IF `crank_rpm` ≥ object's mass threshold
- Mass thresholds:
  - Post-it / scrap of paper: 5 RPM
  - Floppy disk: 20 RPM
  - Modem: 60 RPM
  - Server rack: 200+ RPM (sustained)
  - Refrigerator: 300+ RPM (sustained)
- Attached object follows the d-pad cursor
- A places, B throws (force = current RPM at release)
- Reverse crank = pull toward player from distance
- Sustained 200+ RPM heats the coil; at `heat >= 100` the NeoPixels go red, attachment force-drops, 3-second cooldown before next heavy lift

---

## 5. The Tyson master unlock

**Code:** `007-373-5963` — the password to skip directly to Mike Tyson in **Mike Tyson's Punch-Out!! (NES, 1987)**. Mythological among NES-era kids.

### Implementation

- Walk newb to the **Tyson Cabinet** in the playground (or use the glove directly in narrative scenes per spec)
- A-press opens the digit-entry UI (the cabinet IS the entry point in the playground — no gesture discovery needed)
- Crank scrolls 0–9 (36° per digit step — 10 digits in 360°)
- A-press commits the current digit and auto-advances cursor, skipping the dashes at positions 4 and 8
- Enter the full 11-slot sequence `007-373-5963`

### On match
- All PWNGLOVE power layers cascade-unlock (Flipper suite all 6 tools + portal_gun + gravity_gun, in addition to konami which was already active)
- `save_state.flags.tyson_unlock = true` persists across sessions
- NeoPixel full rainbow sweep + screen overlay `★ TYSON MODE ★` for 3 seconds

### On mismatch
- Resets to position 1 + dialog "That's not it. Try again."

### Already-granted state
- Cabinet shows "ALREADY GRANTED — 1987" with the year etched on the glass

### Anti-cheese
Tyson unlocks **tools**, not **story gates**. Aegis Datacenter still requires Act 3 narrative progress. SecKC hive still requires the Knuckleheads invitation. The cheat code is for replays, speedruns, and showing off — it doesn't break the narrative gates.

---

## 6. Crank as power channel — the unifying mechanic

The Playdate crank is the PWNGLOVE's **physical power source**, not a UI selector. Every layer reads from a single shared `pwnglove_hud.crank_rpm` global. NeoPixel array brightness = `crank_rpm / max_rpm`. Sustained 200+ RPM heats the coil via `pwnglove_hud.heat`.

This is what makes PWNGLOVE feel like a coherent device with an energy budget, rather than a menu of unlocked abilities. It also gives HAKCD the platform-and-game alignment of *Mars After Midnight* / *Crankin's Time Travel Adventure* / *Casual Birder* — crank as first-class input.

### Per-layer crank formulas (canonical)

```
Konami:    attempts = 30 + log(1 + revs_post_konami) * 25, asymptote 100

Flipper:
  RFID_CLONE:      accumulate at crank_rpm * dt, decay 5/sec idle, threshold 50
  SUB_GHZ:         signal_dB = clamp(crank_rpm / 10, 0, 30), capture at >= 15
  IR_LEARN:        intensity = crank_rpm * 0.5, range_meters = intensity / 10
  BLUE_BOX:        tone_hold_duration_sec = total_revs * 0.2
  IBUTTON:         emulation_freq_hz = crank_rpm * 100, lock ±5 Hz at 6000 Hz
  BAD_USB:         chars_per_sec = clamp(crank_rpm / 2, 1, 60)

Portal:
  energy_per_rev: 1.0
  thresholds: 0-25 current_act, 25-60 prev_acts, 60-100 incl seckc_hive
  collapse_below: 25 (use consumed)

Gravity:
  required_rpm: post_it 5, floppy 20, modem 60, server_rack 200, fridge 300
  heat: +1/sec when rpm > 200, -10/sec otherwise
  overheat_at: 100 → forced drop + 3s cooldown
  throw_force: rpm at release

Tyson:
  digit_count: 11 (9 digits + 2 auto-dashes)
  digit_advance: A press
  digit_commit (full spec): reverse-crank flick ≥ 60 RPM in 250ms window
  (Tier-1 hakcd-v4 simplification: A also commits, reverse-flick is the future enhancement)
```

These formulas are canonical — they're not just runtime tuning, they're part of the **game feel contract**. Tuning them is a coordinator-approved change, not an agent-level edit.

---

## 7. The nine playground stations

The playground room is a single hand-authored scene (`source/scenes/PlaygroundScene.lua` in hakcd-v4) with nine interactive hotspots. The player walks newb between them with the d-pad. Each hotspot has a label and an A-press handler.

### Layout

```
+---------------------------------------------------+
|  [PWNGLOVE MODE neon sign banner]                 |
|                                                   |
|  [LOCKPICK]     [RFID]      [PAYPHONE]  [IR WALL] |
|                                                   |
|  [GRAVITY]      [SUBGHZ]    [PORTAL]    [VAULT]   |
|                                                   |
|                  [TYSON CABINET]                  |
|                                                   |
|              [newb spawns here]                   |
+---------------------------------------------------+
```

Mapped onto a 17×10 LDtk grid in `source/levels/world.ldtk` with the `Playground` level + `Hotspots` entity layer + `Collision` IntGrid layer.

### Station-by-station

#### 1. LOCKPICK STATION

Practice deadbolt mounted on a workbench. PWNGLOVE arm hovers above. **Visual reference:** `docs/lockpickmini.png` (Lucas Pope-tier UI density bar).

**Mechanic:**
- 5-pin standard lock, 3 attempts, 60-second timer
- Crank rotates the AIM compass (0–359°)
- Each pin has a hidden binding zone (45°–90° arc centered randomly)
- A-press locks the current pin if AIM is in the zone; advances to next pin
- A-press outside the zone = SNAP, all pins reset, attempt consumed
- Tension meter rises with each A-press (+0.15 per press)
- STOP/CARE/SAFE zones on the tension meter
- Tension > 100% in STOP zone = forced reset

**Audio:** `lockpick_crank_turn` (low metallic rasp loop), `lockpick_pin_click_1..4` (sharp brass click variants), `lockpick_tension_warn` (rising whine), `lockpick_open` (clunk + 4-tone brass arpeggio 440-554-659-880 Hz), `lockpick_snap` (harsh buzz)

**Newb dialog reactions:**
- Pin 1 set: "Easy. Standard pin."
- Pin 3 set: "Pin three. Steady on the crank. Almost there."
- Tension high: "Easy. Easy. Don't snap it."
- Lock open: "Clean. Knuckleheads style."
- All attempts failed: "Snapped the tension wrench. Try again."

#### 2. RFID PEDESTAL

Wall-mounted RFID reader with a status light + demo badge on adjacent pedestal. **Visual reference:** `docs/pwnglove_remotehack.png` (concentric arcs from glove + floating `0xA8F2 / AUTH / OK` text + parking garage backdrop).

**Mechanic:**
- A on badge → PWNGLOVE extends, cloning meter appears
- Crank charges 0..50 units; decays 5/sec when idle
- At 50 units the badge is read — `0xA8F2 / AUTH / OK`
- A on reader → emit cloned signal
- Door buzzes open (animation, no destination — demo only)

**Audio:** `rfid_capture_chirp`, `rfid_emit_burst`, hydraulic door clunk

**Newb dialog (the canonical 'Knuckleheads' line is verbatim):**
- Approach: "Some chump left it here. Easy capture."
- Capturing: "Cranking the read coil. Hold steady."
- Captured: "Got it. Badge ID 0xA8F2. Auth signature clean."
- Emit: **"Cloned. Now I'm someone else for ninety seconds. Knuckleheads taught me well."**

#### 3. PAYPHONE / BLUE BOX

Period-accurate payphone mounted on a brick wall. Receiver in cradle. Coin slot.

**Mechanic:**
- A picks up the receiver
- Crank tunes a continuous tone across 200–4000 Hz
- Lock onto 2600 Hz ± 80 Hz window
- Hold the lock for 3 seconds → trunk seizes
- Free long-distance dialer overlay (A appends digits, B abandons)

**Audio:** receiver clatter, continuously variable sine wave, 2600 Hz lock (stabilize + echo), CCITT trunk-seize signaling, era-appropriate dial tone

**Newb dialog:**
- Pick up: "Bell pedestal. Old school."
- Tuning: "Looking for the magic number."
- Locked on 2600: "There it is. Trunk's mine."
- Hold: "Holding the tone. Keep cranking."
- Trunk seized: "I'm in. Free long distance. Used to be a felony."

**Visual flourishes:** brick wall texture + graffiti including a small `2600` tag and an anarchist A

#### 4. IR WALL

90s living room — CRT TV on a wheeled cart + IR-locked door + keypad. Shag carpet.

**Mechanic:**
- D-pad cycles target between `[TV]` and `[IR DOOR]`
- A enters charging mode
- Crank charges IR LED intensity 0..100 (0.7 per degree, decays 0.05/ms idle)
- A again with intensity ≥ 50 → emit pulse
- TV: TV-B-Gone collapsing-line die animation (800ms), then dialog "Off. Stay off."
- Door: 500ms emit then door swings ajar, dialog "Click."

**Audio:** IR LED whine (visual only — silent), CRT die (whoomp + static), door unlock (chirp + servo)

**Newb dialog:**
- TV approach: "Hate that thing."
- Emit at TV: "Off. Stay off."
- Door approach: "IR lock. Standard model. Probably 38kHz carrier."
- Door open: "Click."

#### 5. GRAVITY ARENA

Open warehouse floor with scattered movable objects: floppy disk, modem, server rack, refrigerator. Target ring painted on the concrete floor.

**Mechanic:**
- Cursor crosshair navigates with d-pad
- A on object attaches if `crank_rpm ≥ mass_threshold` (FLOPPY 20, MODEM 60, RACK 200, FRIDGE 300)
- Attached object follows cursor
- A places, B throws (force = `(1 + rpm/50) * last_cursor_velocity`)
- Reverse crank = pull-toward from distance
- Sustained 200+ RPM heats coil; at `heat = 100` NeoPixels go red, attachment force-drops, 3s cooldown
- Placing the server rack inside the target ring increments `placed_in_ring_count` (optional easter egg)

**Audio:** coil spin-up (rising EM whine), attach (metallic clank), move (low hum), heavy lift (strained whine), throw (whoosh + thud), overheat (sputter + cooldown beep)

**Newb dialog:**
- Floppy: "Light work."
- Rack: "This is what the EMF coil's for."
- Overheat: "Coil's red. Drop it."
- Hit target ring: "Placed. Cleanly."

#### 6. SUBGHZ TUNER

Garage door at one wall + cordless phone receiver on a workbench.

**Mechanic:**
- D-pad cycles target between `[GARAGE]` (315 MHz rolling code) and `[CORDLESS]` (49 MHz call)
- Crank powers the antenna: `signal_dB = clamp(rpm / 10, 0, 30)`
- Broadcast window opens every ~3.7s, lasts 1.5s — capture during the window with signal ≥ 15 dB
- Garage capture → A replays → door opens
- Cordless capture → A replays → transcript scrolls (period gossip with the punchline "She doesn't know I'm at Knuckleheads tonight")

**Audio:** antenna spin-up (low static), signal capture (warble locking in), replay (muffled radio chatter, dithered sub-1GHz sample), garage motor whine + chain rattle

**Newb dialog:**
- Garage: "Standard 315MHz garage opener. Common as dirt."
- Capture: "Got the rolling code chunk. Lucky timing."
- Replay: "Open sesame."
- Phone: "Cordless on 49MHz. People still use these?"

#### 7. PORTAL PEDESTAL

Glowing plinth with three holographic scene previews floating above (bedroom, SecKC hive, Aegis — last one greyed + padlock).

**Mechanic:**
- A enters portal mode
- D-pad scrolls destination list
- Hold B + crank to charge `portal_energy` 0..100
- Thresholds 0-25 / 25-60 / 60-100 gate which destinations are selectable
- Release B with energy ≥ 25 → warp
- Release B with energy < 25 → collapse + use consumed
- Aegis Datacenter shows `STORY GATE: REQUIRES ACT 3` flash if selected

**Audio:** portal charge (rising harmonic), select (chime), warp (teleport whoosh), locked (denial buzz)

**Newb dialog:**
- Approach: "Cached handshakes. The glove remembers every BBS I've cracked."
- Charging: "Spinning up the dialer."
- Warp: "Re-dialing."
- Locked: "Aegis is hardened. Can't warp in. Have to walk."

#### 8. COIN VAULT

Pedestal between the portal and Tyson stations. 23 C0iNS grid viewer matching `docs/coingame.png` reference exactly. Display-only — no minigame, just a close-up showcase of the most visually distinct asset family in the project.

**Layout** (per `docs/coingame.png`):
- Top bar: `HAKCD > 23 C0iNS` with indicator arrow
- Main 4×6 grid of 24 coin cards
- Right sidebar:
  - `MINTED: N / 24`
  - `STATUS: <coin title>`
  - Large coin closeup with starburst rays
  - Canonical rule text: "Solving the entire coin earns you the next coin regardless of solve status."
  - Footer: skull-bracket `[ 23 C0iNS ]`
- Bottom dialog bar with newb portrait

**Real coins shipping in v0.1.x** (sourced from [`NoDataFound/23Coins`](https://github.com/NoDataFound/23Coins) — the real-world 23 C0iNS minting project):
| Coin | Title | Reference |
|---|---|---|
| 0 | WELCOME COIN | `docs/coin0.png` — 23 C starburst |
| 1 | ROTARY DIAL | `docs/coin1.jpg` — phone dial + Bacon cipher border |
| 2 | LOST WAGES | `docs/coin2.jpg` — Speak & Spell + Francis Bacon + PBEL cavern |
| 3 | YODA HASH (placeholder) | `docs/coingame.png` — pending hand-pick |

Coins 4–23 show a generic locked card with `???`.

**Playground behavior:** all 24 coins are unlocked for browsing (showcase mode), bypassing the story phrase-discovery gates that lock them in narrative mode.

**Mechanic:**
- D-pad navigates the grid (wraps within bounds)
- A zooms to closeup view with sidebar detail
- B returns to grid; second B exits viewer back to playground

**Audio:** `vault_door_open` on enter, `vault_door_close` on exit, `coin_navigate_tick` on d-pad, `coin_zoom_whoosh` on A-zoom

**Newb dialog samples (per coin):**
- Coin 0 grid: "Coin Zero. Minted on first visit. Phrase locked. Coin One waiting. Let's see what it wants."
- Coin 0 closeup: "Twenty-three. The number SecKC chose. Year I started cracking BBSes."
- Coin 1 grid: "Coin One. Phone dial. Phreaker shit. The border text rotates — that's a Bacon cipher or I'm an idiot."
- Coin 2 closeup: "PBEL. That's PBEL backwards. Or anagrammed. Or both."
- Coin 3 grid: "Coin Three. Yoda. With a hash tattoo. Sure."

#### 9. TYSON ARCADE CABINET

Full arcade cabinet against the back wall. Marquee reads `MIKE TYSON'S PUNCH-OUT!!` with classic NES art. CRT inside shows the title screen.

**Mechanic** (per Layer Tyson above):
- A opens digit-entry UI directly (the cabinet IS the gesture entry point)
- Crank scrolls 0–9, A commits + advances cursor, auto-skips dashes at positions 4 and 8
- Enter `007-373-5963`
- On match: cascade-unlock all layers + 3s `★ TYSON MODE ★` overlay + persist `save_state.flags.tyson_unlock = true`
- Already-granted shows `ALREADY GRANTED — 1987` etched on cabinet glass

**Audio:** cabinet approach loop (period-accurate arcade attract music), digit confirm (click), wrong code (harsh buzz), correct (`tyson_winner` — Punch-Out WINNER homage: C5 → E5 → G5 → C6 ascending arpeggio + sustained C major triad), unlock (full rainbow sweep + crowd cheer)

**Newb dialog:**
- Approach: "Knew there was a code. Heard it from a kid at the arcade in '88."
- Wrong code: "That's not it. Try again."
- Correct: "Seven digits. Three-seven-three. Five-nine-six-three. Mike Tyson's password."
- Post-unlock: "Everything's mine now."

---

## 8. The 4-LED bend-sensor HUD

A compact visualization always rendered at the top-left of the playground free-walk view (not during full-screen modals). Synthesizes the real PWNGLOVE's 4-finger bend output (thumb / index / middle / ring) as a 4×5-LED row.

Each finger's LED count = `bend / 51` (0–5 LEDs lit). Bend values are computed from `crank_rpm` plus a per-layer animation pattern.

### Per-layer NeoPixel patterns

| Active layer | Pattern |
|---|---|
| `rfid` | Sweep T → I → M → R every 800ms |
| `ir` | Blink all (300ms cadence) |
| `portal` | Progress bar fills T then I then M then R as RPM crosses 90 / 180 / 270 / 360 |
| `gravity` | Outer-bright (T, R), inner-dim (I, M) ring effect when attached |
| `tyson` | Rainbow simulated via 4 sin phases offset by 1.5 rad each, 200ms period |
| `konami` | Pulse all-on (300ms sin) |
| (default / none) | Uniform `crank_rpm`-scaled |

Real PWNGLOVE firmware reads 4 analog bend sensors through a multiplexer on pin 3; the in-game synthesis above emulates that telemetry deterministically from the crank input.

### Bottom 20-LED brightness strip

Separately, a 20-dot horizontal strip across the screen bottom shows overall NeoPixel brightness as a fraction of `crank_rpm / max_rpm`. At `heat > 75` the strip enters a red-checker overheat-warning mode.

---

## 9. MASTER HAKCER achievement

Track per-station visited flags. Visit all 9 stations → animated achievement card fires.

### Card spec

- 4-second BIG center card 320×110 with double-line frame
- 12 radial rays from center (60–180 px radius)
- Title: `* ACHIEVEMENT UNLOCKED *`
- Name: `MASTER HAKCER`
- Subtitle: `All 9 PWNGLOVE stations visited`
- 9 station-checkmark badges in a row
- `konami_unlock` SFX (Punch-Out WINNER homage)
- Persists `save_state.pwnglove_mode_complete = true`

### Post-unlock

Card fades to a small persistent top-right corner badge `V MASTER HAKCER` on subsequent visits — doesn't replay the full animation.

---

## 10. Save state architecture

The playground uses Noble's checkpoint API (in hakcd-v4) wrapping `playdate.datastore`. Schema:

```
save_state.flags:
  handle              : string (default "newb")
  current_act         : int   (1..4)
  completed_scenes    : table { [scene_id] = true }
  inventory           : array<item_id>
  unlocked_tools      : array<tool_id>
  scene_state         : table per-scene persisted state
  scripted_event_timers : table { [event_name] = next_fire_ts }
  pwnglove            : PwngloveState (typed subtree, see below)
  coins               : table<id, CoinState>
  pwnglove_mode_complete : bool
  tyson_unlock        : bool

save_state.checkpoints:
  pre_pwnglove_mode   : deep-copy of flags (used by system menu push/restore)
```

### PwngloveState subtree

```
pwnglove:
  equip_state: 'holstered' | 'equipped'
  layers:
    konami:
      unlocked: bool (true when equipped)
      state: 'idle' | 'buffering' | 'konami_armed' | 'konami_consumed'
      bonus_attempts: int (0 unless armed)
    flipper:
      tools_unlocked: { rfid_clone, subghz_replay, ir_learn, ibutton_emulate, blue_box, bad_usb }
      active_tool: tool_id or nil
      charge: per-tool meter 0..100
    portal:
      unlocked: bool
      portal_energy: 0..100 (live during charge)
      uses_remaining_this_act: int (refills at act transition)
    gravity:
      unlocked: bool
      attached_object_id: id or nil
      heat: 0..100
      cooldown_until_ms: timestamp (0 if cool)
  tyson_unlock: bool (cascade-flips all layers.unlocked = true)
```

### CoinState subtree

```
coins:
  '0': { id=0, state='locked'|'available'|'minting'|'minted',
         phrase_known=bool, puzzle_complete=bool, hints_seen=array<id> }
  '1': { ... }
  ...
  '23': { ... }
```

Coin 0 ships as `state='minted'` by default (welcome coin).

---

## 11. Visual references — the canonical pins

These six display-only assets are **pipeline-guarded**. The image-generation pipeline NEVER regenerates them. `sdk_main_emitter.js` (legacy) and the hakcd-v4 launcher / scene loaders hard-copy them from canonical source paths:

| Asset id | Source path | Use |
|---|---|---|
| `title` | `docs/hakcd_title.png` | Title screen + launcher card derivatives |
| `pwnglove_icon` | `docs/gamepwnglovev2.png` | 1.5s intro splash + HUD corner + inventory equip + polaroid (baked into title) |
| `coin_0` | `docs/coin0.png` | 23 C0iNS Coin 0 — welcome |
| `coin_1` | `docs/coin1.jpg` | 23 C0iNS Coin 1 — rotary dial / Bacon cipher |
| `coin_2` | `docs/coin2.jpg` | 23 C0iNS Coin 2 — Lost Wages / Speak & Spell |
| `coin_3` | `docs/coingame.png` | 23 C0iNS Coin 3 placeholder (Yoda hash TBD) |

Lineage matters: title + coins come from the real `NoDataFound/23Coins` project. PWNGLOVE icon is the already-rendered 1-bit game asset. The fictional HAKCD universe is anchored in the creator's actual work — anyone who recognizes them gets the inside reference; anyone who doesn't gets beautiful weird art with newb's deadpan commentary. Both audiences served.

---

## 12. The lockpick UI is the proof bar

The lockpick station is the **load-bearing deliverable** for the whole platform. Why:

- The reference image (`docs/lockpickmini.png`) is **Lucas Pope-tier UI density**: top bar with `PUZZLE: 5-PIN STANDARD | ATTEMPT N/3 | 0 POINTS | hourglass 0:47 | PUZZLE IN PROGRESS`, center 5-pin tumbler cutaway with BINDING ZONE compass + 5 numbered pin slots + UNLOCK ZONE label spanning all 5, right-side TENSION meter with STOP/CARE/SAFE bands and a current marker, bottom controls strip `[CRANK] AIM | [A] LOCK PIN | [B] ABANDON`, bottom dialog bar with newb portrait reacting per pin
- If the lockpick lands at 85%+ of the reference, the demo carries
- If it lands at 60%, the whole sprint reads as "tech demo with a placeholder minigame"

Tier-1 acceptance for tonight's hakcd-v4 ship: compass + 5 numbered pin slots + tension STOP/CARE/SAFE bars with marker + controls strip + dialog bar with portrait box, all rendered via primitives + one generated 1-bit lock body sprite. Hand-pixel upgrade path preserved.

---

## 13. Acceptance tests

### Boot path
1. Power on Playdate / Simulator → canonical title splash (`hakcd_title.png` derivative on the launcher card; full title PNG in-game)
2. Press A → BedroomScene loads with LDtk-tiled floor and Newb sprite walking via d-pad

### PWNGLOVE MODE entry
3. Hardware menu button → "pwnglove mode" → 1.5s glove intro splash → PlaygroundScene

### Lockpick station
4. Walk newb to LOCKPICK STATION → A → 5-pin lockpick UI matching `docs/lockpickmini.png` density
5. Crank → AIM compass rotates
6. A on pin in binding zone (45°–90°) → pin sets, dialog "Easy. Standard pin."
7. A on pin outside zone → SNAP, attempt decrement, all pins reset
8. Solve 5 pins → "** LOCK OPEN **" + `lockpick_open` SFX + dialog "Clean. Knuckleheads style."

### Tyson cabinet
9. Walk to TYSON CABINET → A → digit-entry UI
10. Crank 0–9, A commits, enter `007-373-5963`
11. Match → `★ TYSON MODE ★` overlay 3s + `tyson_winner` arpeggio + persisted `flags.tyson_unlock`

### Coin Vault
12. Walk to COIN VAULT → A → 24-card grid + sidebar matching `docs/coingame.png`
13. D-pad navigates, A zooms (closeup of coins 0–3 from canonical pins), B unzooms, second B exits viewer

### All 9 stations
14. Visit each station once → MASTER HAKCER 4-second card + persisted `pwnglove_mode_complete`

### Story return
15. Hardware menu → "back to story" → checkpoint restored → returns to title (or last scene)

If all 15 land clean, PWNGLOVE MODE is shipped per spec.

---

## 14. Current build state

| Repo | Tag | Build status |
|---|---|---|
| `darkcodelabs/hakcd-v4` | `v0.1.0` | Foundation rewrite ships, Noble-default launcher bug |
| `darkcodelabs/hakcd-v4` | `v0.1.1` | Launcher fix (canonical HAKCD tile) |
| `darkcodelabs/23Studios` | `hakcd-v0.0.4..v0.0.8 + v0.1.0` | Legacy v0.0.3-line; pre-foundation rewrite |

hakcd-v4 is the active line. Built on Noble Engine + LDtk + AnimatedSprite + GFXP. Each commit that changes the shipped `.pdx` gets its own version tag — no clobber, traceable history.

Sideload:
```
gh release download v0.1.1 -R darkcodelabs/hakcd-v4 -p hakcd_v0.1.1.pdx.zip
unzip hakcd_v0.1.1.pdx.zip
# Drag hakcd.pdx onto Playdate device or Simulator
```

Smoke test order: title → A → bedroom → menu → "pwnglove mode" → walk to TYSON CABINET → enter `007-373-5963`. Everything lights up.

---

## 15. Demo video flow (90-second cut)

| Time | Beat |
|---|---|
| 0–5s | Title splash (canonical `hakcd_title.png`) |
| 5–15s | Menu → "pwnglove mode" → glove intro splash 1.5s → walk into room, neon sign flickers on |
| 15–25s | Lockpick station — crank, pin clicks, dialog, lock opens |
| 25–35s | RFID pedestal — capture, emit, "Cloned. Now I'm someone else for ninety seconds. Knuckleheads taught me well." |
| 35–45s | Payphone — crank, 2600Hz lock, trunk seize |
| 45–55s | Gravity arena (server rack lift) |
| 55–60s | Coin vault rapid scroll (4 real coins + newb deadpan) |
| 60–70s | Portal gun |
| 70–85s | Tyson cabinet — `007-373-5963` → TYSON MODE |
| 85–90s | Outro — "HAKCD — coming whenever it's ready" |

Every beat lands. Sound design carries the energy. Viewer either gets it immediately or they're not the audience.

---

## 16. Source-of-truth doc index

For the original specs that informed PWNGLOVE MODE:

| Spec | Location |
|---|---|
| Multi-tool layers + Tyson | `23studios/docs/phase5_pwnglove_multitool_addendum.md` |
| Crank-as-power-channel | `23studios/docs/phase5_pwnglove_crank_power_channel.md` |
| Playground 9-station scene | `23studios/docs/phase5_pwnglove_mode_playground.md` |
| Canonical pins + Coin Vault | `23studios/docs/phase5_canonical_pins_and_coin_vault.md` |
| Coins priority (real-world refs) | `23studios/docs/phase5_pwnglove_coins_priority.md` |
| Phase 5 cross-team contracts | `23studios/server/types/phase5_contracts.js` (CONTRACT_VERSION `5.0.0-day1+pwnglove+crank+playground+canonical_pins+coin_vault+v4`) |

All specs are on the legacy `darkcodelabs/23Studios` repo. They informed hakcd-v4 but are not vendored into it — hakcd-v4 ships a clean Noble Engine foundation with the working pieces ported in.
