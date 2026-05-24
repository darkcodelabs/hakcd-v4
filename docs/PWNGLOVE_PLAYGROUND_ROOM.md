# The PWNGLOVE MODE Playground Room

Standalone description of the room itself — the physical space, the lighting, the set dressing, the atmosphere. For the underlying gameplay see [PWNGLOVE_MODE.md](PWNGLOVE_MODE.md).

---

## The pitch

It's a **hacker's clubhouse basement** somewhere in 1998. Concrete floor, mismatched brick-and-plaster walls patched with PVC conduit, drop-ceiling tiles with a fluorescent tube that flickers every 1.5 seconds. Someone has been collecting equipment in this room for a decade and rotating different rigs through it. Workbenches. A wall-mounted payphone wired into a Bell pedestal somebody clearly was not supposed to access. A CRT TV on a cart pointed at nothing in particular. An honest-to-god arcade cabinet bolted to the wall against the back. A pedestal in the corner glowing in a way that doesn't match anything else in the room.

The room is **400×240 pixels** at 1-bit dithered Playdate scale. Top-down isometric perspective with a slight depth bias — closer-to-the-camera objects sit lower, farther-from-camera objects sit higher. Roughly 17×10 tiles at 24×24 px per tile gives the playable floor space.

newb spawns center-bottom, facing north (toward the back wall). The neon sign across the top reads **PWNGLOVE MODE** and pulses on and off every 1.5 seconds — when on, full word; when off, the letters flicker between `PWN` and `GLOVE` like a dying tube sign.

---

## Floor

**Material:** scuffed industrial concrete, dithered as a sparse Bayer 4×4 pattern with occasional darker patches where oil or solder flux has stained. The dither isn't uniform — the high-traffic lane between the workbench and the arcade cabinet is worn smoother (lighter pattern density) than the dead-zone corners.

**Target ring:** a hand-painted yellow ring approximately 60 pixels in diameter on the floor in front of the gravity arena. The paint is chipped — the perimeter line breaks up into a dithered ring with gaps every ~20°. In the center of the ring, the word `TARGET` is stenciled in 6×8 px caps. This is the placement target for the gravity gun's server-rack lift.

**Scattered debris:** small dithered specks throughout the floor — bits of brass shaving near the lockpick station, foam packing peanuts near the gravity arena, a flattened can of TaB near the arcade cabinet. None of these are interactive; they're set dressing that reads as "people use this room."

---

## Walls

The room is bordered on all four sides. The walls don't match — three are brick (one painted, two raw), and the back wall is industrial plaster with exposed drywall scars where someone has cut access ports for cabling.

### Brick walls (left, right, partial back)

Dithered as a 24×8 px tile pattern with horizontal mortar lines every 6 px and vertical lines staggered for the running-bond brick pattern. Some bricks are darker (kiln overfire) — those provide visual texture and break the regularity.

**Painted brick (left wall, behind payphone):**
- Black paint covers most of the surface, deliberately incomplete — about 15% of the brick shows through where the paint is chipped
- Hand-applied **graffiti tags**:
  - A small `2600` tag in stenciled letters near the payphone (the magazine reference)
  - An anarchist `A` in a circle next to the 2600 tag
  - A faded `PHRACK` logo higher up, partially worn
  - A small skull-and-crossbones near the floor with `[ 23 ]` underneath it (foreshadow for the coin vault)
- A row of phone numbers scratched into the paint with what looks like a key, mostly illegible (period-accurate hacker meeting board)

### Plaster back wall

- Off-white plaster with visible patch jobs (darker rectangles where holes have been filled in)
- An **EMPLOYEE OF THE MONTH** frame hangs crooked near the RFID pedestal — inside the frame is a photo of someone too small to make out clearly, but with a hooded silhouette suspiciously similar to newb's
- A **PIRATE FLAG** posted with masking tape next to it — black field, white skull
- A small framed **MagPi Issue 33 cover** next to the EOTM frame — the actual real-world artifact, included as an easter-egg reference to the PWNGLOVE device's documentation
- **Exposed PVC conduit** runs horizontally across the back wall at about 2/3 height, with split-off branches dropping down to each station — visual storytelling that the room was wired specifically for all this equipment

### Drop ceiling

Not directly rendered (top-down view), but **inferred** by:
- The **fluorescent tube flicker** that affects ambient lighting (the neon sign banner mimics this with its flicker pattern)
- The hanging cable that suspends the **CRT TV** at the IR wall — visible as a thick vertical line dropping into the TV's bracket
- **One ceiling tile slightly askew** above the portal pedestal — the corner is bent down as if something was pulled through it recently

---

## Lighting

The room is rendered in 1-bit but reads as **dim with localized hotspots**. The base background dither favors black (~40% lit) — about as dark as a basement in 1998 with one main light and a few task lamps.

**Lit areas:**
- The neon `PWNGLOVE MODE` sign across the top — bright white when on, full black when flickering off
- The portal pedestal — emits a constant Bayer 4×4 ambient glow in a ~80px radius
- The arcade cabinet's marquee — backlit, casting a small light wash in front of it
- The lockpick workbench has a small **gooseneck task lamp** clamped to the bench, throwing a small bright pool over the deadbolt
- When **newb has PWNGLOVE equipped** (always true in the playground), the NeoPixel finger row casts faint light on newb's body that varies with `crank_rpm` — visible as small dithered halos around the sprite when cranking hard

**Unlit / shadow areas:**
- The corners between the stations are darker — heavier dither
- The space directly above the floor (between hotspots and the wall) is darker, suggesting raked lighting from above only

---

## Station-by-station set dressing

Each of the nine stations has a vignette. These are described counter-clockwise starting from the top-left corner.

### 1. Lockpick station (top-left)

**Set:** A heavy wooden workbench bolted to the brick wall. The bench surface is gouged and stained from years of use. A small **gooseneck task lamp** clamps onto the front edge of the bench and throws a pool of light over the work area.

**Props laid out on the bench:**
- Eleven thin **picks and tension wrenches** in a row, standing upright in a brass holder
- A **brass deadbolt** clamped in a small vise, exposed on the cutaway side so the player can see the pin tumblers
- A **small magnifying loupe** on a swing-arm
- A **coffee mug** with `KNUCKLEHEADS` printed on it in distressed caps — half-empty, lipstick mark on the rim
- A scatter of **brass shavings** on the bench surface
- An open **PROPERTY OF KNUCKLEHEADS** stencil leaning against the wall

**Above the bench:** A small framed certificate from the **Knuckleheads Locksport Club** with newb's handle on it (`@newb — Level 3 Solver`).

**newb's interaction:** Approaching the bench triggers the prompt `[A] LOCKPICK`. Pressing A opens the full Lucas-Pope-density lockpick UI per `docs/lockpickmini.png`.

### 2. RFID pedestal (top-middle-left)

**Set:** A small marble-topped pedestal in front of the back plaster wall. On the pedestal: a generic **office badge** with `EMPLOYEE 0xA8F2` printed on it in tiny text. Wall-mounted next to the pedestal: a **commercial RFID badge reader** with a status light (currently red).

**Surrounding props:**
- A **potted ficus** in the corner, leaves dithered into a rough green-gray mass
- The **EMPLOYEE OF THE MONTH** frame above the pedestal (with the suspicious hooded photo inside)
- A small **CCTV monitor** on a swing-arm bracket showing the room itself from a high corner — visible as a tiny inset with a slightly delayed dithered view of newb walking around (a meta-detail — the camera is watching)
- An **AUTHORIZED PERSONNEL ONLY** door behind the pedestal (rendered as a 60×100 px metal door with a doorknob and a small slot for the badge reader on the doorframe)
- A small **DO NOT TOUCH** sign on a chain hanging from the pedestal — newb ignores it

**Lighting:** The reader's status light pulses when newb is within capture range, switches to green when the badge is cloned.

### 3. Payphone (top-middle-right)

**Set:** A standard **Bell payphone** wall-mounted on the painted-brick wall. Receiver hangs in cradle. Coin slot. The chrome is scratched and the back of the receiver has a wad of dried gum stuck to it. The coin-return slot is visibly bent — somebody pried it.

**Surrounding props on the brick:**
- The `2600` graffiti tag, the anarchist `A`, and the scratched-in phone numbers
- A **rotary-dial sticker** stuck above the keypad that says "DIAL DOWN" with an arrow
- A **handwritten note** taped at eye level: "out of order — don't fix it" (irony — it works perfectly)
- A small **PHRACK 49** zine pinned to the brick with a thumbtack

**Floor:** Cigarette butts and a flattened TaB can under the payphone.

**newb's interaction:** A picks up the receiver and starts the blue-box tuning interface.

### 4. IR wall (top-right)

**Set:** A small 90s-style living-room vignette built against the right wall. Includes:
- A **CRT TV** on a wheeled cart (the kind with metal mesh shelves and rolling casters), face-out, screen showing dithered static when alive
- A worn **shag carpet** in front of the TV (rendered as a dithered ~80×60 px patch with longer fiber details suggested by vertical scratch marks)
- An **IR-locked door** to the right of the TV — black-painted steel with a small keypad and IR receiver embedded next to it
- An **IR remote** on top of the TV (irony — newb is going to bypass it with the glove)
- A **VHS recorder** under the TV with `EJECT` button visible and a dangling tape sticking out at an awkward angle

**Ambience:** The CRT throws **flickering light** onto the surrounding floor when it's alive — a slow scanline shimmer rendered as a horizontal Bayer band that scrolls down the TV's screen at 30 px/sec. When killed by TV-B-Gone, the screen collapses into a single horizontal line then black.

### 5. Gravity arena (bottom-left)

**Set:** An open patch of concrete with the painted target ring + scattered movable objects:

- **Floppy disk** (5.25", labeled `WAREZ` in marker) — light, 20 RPM threshold
- **External modem** with cable trailing off-screen — medium, 60 RPM
- **Server rack** (rack-mount, 4U high, blinkenlights on the front) — heavy, 200+ RPM
- **Refrigerator** (mini-bar size, with a faded Coca-Cola logo) — very heavy, 300+ sustained
- A discarded **chip bag** (placed inside the target ring for scale, ignored by mechanic)

**Wall behind:** raw brick. Plain. No tags here — this is the "work area" where physical lifts happen.

**Above the arena, on the wall:** A small framed photo of a famous gravity-gun moment (a reference to a beloved game's iconic lift sequence) — dithered down so it reads as "some game on a frame" without being identifiable. Easter egg.

### 6. SubGHz tuner (bottom-middle-left)

**Set:** A small **garage workbench** with cables hanging from the wall above. On the wall opposite the bench (rotated for top-down view) is a **garage door** with horizontal slats. On the bench: a **cordless phone** in its charging cradle.

**Props on bench:**
- Soldering iron in a stand (cold)
- A **multimeter** with leads coiled
- An **antenna whip** sticking up from a small wooden block
- Three or four **circuit boards** in various states of disassembly
- A **MOTOROLA PAGER** clipped to the workbench edge

**Garage door:** Has a small chain rail above it (suggested by short vertical lines). Below the door, a hand-lettered sign reads `OUT FOR REPAIRS — USE BACK ENTRANCE`. The door is operable via SubGHz capture.

**Wall ambience:** Hung cables drape in loose loops from ceiling-mount hooks down to a power strip on the floor behind the bench. Visual storytelling that this is the "electronics" corner of the room.

### 7. Portal pedestal (bottom-middle-right)

**Set:** A dark corner of the room. The pedestal itself is a hexagonal pillar, ~40×40 px base, ~50 px tall, with three small **floating holographic scene previews** suspended above it (rendered as Bayer 4×4 dithered rectangles, each ~16×20 px, gently bobbing in a sine-wave pattern):
- Left preview: silhouette of newb's bedroom
- Middle preview: the SecKC hive (warehouse with chairs)
- Right preview: a greyed-out Aegis Datacenter with a small padlock glyph overlaid (story-locked)

**Around the pedestal:**
- A scattered ring of **dried wax** at the base — like someone had been doing rituals here at some point
- A small **dust cover** lying next to it on the floor
- The **bent ceiling tile** is directly above this pedestal — the inference is that the portal previously sucked something through the ceiling and damaged the tile
- A small **post-it note** stuck to the pedestal at finger height that just says `1 USE PER ACT` in pencil

**Lighting:** The pedestal constantly emits a soft Bayer 4×4 ambient glow in an ~80 px radius — the only constantly-lit source in this corner of the room.

### 8. Coin vault (between portal and Tyson)

**Set:** A **display case pedestal** — glass-fronted (rendered as a slightly lighter dither than the surrounding pedestal body to suggest transparency) with a **miniature coin grid** embedded inside. The grid is a tiny 4×6 of the 24 coins, rendered at maybe 4×4 px per cell — readable only as a grid pattern from a distance.

**Surrounding props:**
- A small **brass nameplate** on the front of the pedestal: `23 C0iNS — CURRENT MINTING STATUS`
- A **velvet rope** strung between two small posts in front of the pedestal (museum-style) — newb walks right through it
- A small **placard** mounted on the rope post: `ESTABLISHED 2018 — NoDataFound`
- A **hand-painted skull glyph** with `[ 23 ]` underneath, matching the one on the brick wall — establishing visual continuity for the coin brand

**Lighting:** A small **picture light** clipped to the top edge of the display case throws light down through the glass — visible as a subtle vertical light bar against the coin grid.

**newb's interaction:** A on the pedestal opens the full 24-card grid viewer per `docs/coingame.png`.

### 9. Tyson arcade cabinet (back wall center)

**Set:** A **full-size standup arcade cabinet** bolted to the back wall. The cabinet has the classic NES Mike Tyson's Punch-Out!! art and the cabinet sides are rendered with their distinctive painted-on graphic of Little Mac vs. Tyson silhouettes.

**Cabinet details:**
- **Marquee** at top: `MIKE TYSON'S PUNCH-OUT!!` in bold display lettering, backlit (suggested by a brighter dither above the marquee)
- **CRT screen** showing the title screen with the classic NES boxing menu — Little Mac vs. Tyson silhouettes, "PRESS START"
- **Joystick + 6 buttons** on the control panel
- **Coin slot** on the front cabinet with a `25¢ — 1 PLAY` plate
- A small handwritten note taped to the corner of the cabinet glass: `code: ask cory` (winking)
- The **cabinet glass** has the year `1987` etched in the bottom-right corner (the year of the game)

**To the right of the cabinet:** A **change machine** — coin-op style, with a `OUT OF SERVICE` sign hanging from a chain across the slot. Set dressing only, not interactive.

**To the left of the cabinet:** A **small stool** for the player. There's a half-empty can of TaB sitting on the stool.

**Ambience:** A subtle **arcade attract loop** plays from the cabinet whenever newb is within ~80 px — period-accurate background music at lower volume than the main playground ambient track. When the cabinet is interacted with, the music ducks under the digit-entry SFX.

---

## Ceiling neon sign banner

Across the very top of the room, dominating the visual frame above the stations: a **horizontal neon sign** that reads `PWNGLOVE MODE` in a bold blocky display font, roughly 300×18 px.

**Behavior:** The sign **flickers every 1.5 seconds**. When ON, the full text is rendered solid white-on-black, surrounded by a small ambient glow. When OFF, the surrounding glow disappears and the sign goes to a thin outlined skeleton — but with a twist: instead of just going dark, the sign sequences through `PWN`, then `GLOVE`, then full word — like a partially-broken neon tube that flashes in segments before lighting up fully again.

The flicker pattern is part of the room's signature visual rhythm. It establishes both "this place is alive" and "the wiring is jank, the way you'd expect a hacker basement to be."

---

## Background ambient track

A **low-volume 90s warez-scene chiptune** loops continuously while in the playground (`source/sounds/music/playground_loop.wav` from Bootstrap's normalized keygen scraper output). The track has the distinct chiptune-with-tracker-fills feel of the era — Future Crew, Renaissance, Hornet — appropriate to the visual palette.

**Audio mixing rule:** when newb activates a station's interaction (e.g. opens the lockpick UI, picks up the payphone, enters the coin vault), the **ambient track ducks ~6 dB** under the station's own SFX foreground. When the interaction ends and newb steps back into free-walk, the ambient comes back to full level.

The Tyson cabinet's attract loop is the one exception — it plays at low volume any time newb is within ~80 px, layered on top of the ambient track (not replacing it). Approaching the cabinet creates a localized audio focus zone.

---

## newb's spawn and pathing

newb spawns at **(200, 178)** — roughly center-bottom of the playable area, facing **north** (toward the back wall + arcade cabinet). The first thing the player sees on entering the playground (after the 1.5s glove intro splash) is the room rendered around newb with the neon sign flickering on overhead.

**Walkable area:** Bounded by `x: 8..392`, `y: 14..200` — slightly inset from the screen edges to leave room for HUD overlays.

**Collision:** Defined by the LDtk `Collision` IntGrid layer marking walls + station pedestal bases + workbench fronts as solid. newb cannot walk through them — has to navigate around. Walking-into-wall plays no special animation; just blocks movement.

**Movement feel:** d-pad walks at 2 px/frame in cardinal directions, horizontal-priority on diagonals (per `Newb.lua` from Agent 2 — SPRITE). The walk cycle plays at `tickStep = 6` (10 fps on 60 fps update), giving a deliberate, slightly retro-arcade gait.

---

## Visual quality floor (banned patterns)

The room itself must not violate the **Tetris-B visual quality floor**:

- **No wireframe outlines with empty interiors.** Every shape gets a fill — solid black or GFXP dither pattern (`brick-1`, `vert-1`, `dot-3`, `gray-50`, etc.) per the 136-pattern library.
- **No overlapping text without a draw-layer ordering.** Station labels are part of the LDtk Foreground tile layer; HUD overlays are drawn via NobleScene's `drawForeground` hook AFTER the tile layer.
- **No raw `gfx.fillRect(0, 200, 400, 40)` solid black bars.** Use GFXP-patterned fills for any background panel.
- **No hand-coded `HOTSPOTS = { ... }` bbox arrays.** All hotspots live in the LDtk entity layer.
- **No "default font" rendering for important UI text.** Station labels and HUD text use the chosen game font; only debug overlays may use the default.

If the room ever ends up rendered as outlines + empty boxes + overlapping default-font text, **that's a regression to the v0.0.3 anti-pattern** and the room needs to be rebuilt from the LDtk + GFXP stack.

---

## What the room is meant to feel like

The player walks into this room and immediately gets that it's somebody's **personal workshop / hideout** — not a level designed in a game engine, but a space that has accumulated over time. Every station is a tool somebody actually used. The graffiti is somebody's actual graffiti. The MagPi 33 cover on the wall is somebody's real artifact. The arcade cabinet was bolted to the wall by somebody who actually wanted it there.

The hooded silhouette of newb walking through this room is meant to read as the player **finally getting to see the room they've been hearing about** — the place where the protagonist actually builds and tests the rigs that show up across the rest of the game. PWNGLOVE MODE isn't a separate game mode; it's a peek behind the curtain at the protagonist's workshop, available at any time via the system menu because the protagonist would obviously have access to it at any time.

That's the meta-narrative justification for why the system menu — a Playdate-hardware-level UI element — is the access mechanism. The player isn't entering a "menu screen"; the player is choosing to step out of the current story moment and into newb's workshop. The hardware menu button maps onto "physically leaving wherever you are and going home."

When newb's done in the room, the hardware menu takes them back to wherever they were. Their work in the room **persists** (Tyson unlock writes to save_state; all 9 visited writes the `MASTER HAKCER` flag). The workshop is real and continuous, not a sandbox sequestered from the main game.

That's the room.
