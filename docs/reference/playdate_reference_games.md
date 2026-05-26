# Playdate Reference Games — HAKCD Visual Targets

These six titles are the visual bar for HAKCD. Every authoring decision should reference at least one of them. When in doubt, ask: *which of these games solved this problem already, and how?*

Style-guide cross-reference: §11 of `docs/style_guide.md`.

---

## Mars After Midnight

- **Title:** Mars After Midnight
- **Author:** Lucas Pope (3909 LLC), 2024
- **Genre:** Door-answering / face-matching narrative — closest mechanic relative: *Papers, Please* with telepresence.
- **Visual specifics worth stealing:** Hand-pixel protagonist at roughly 64 px tall with full-body articulation; expressive incidental animation (head turns, idle shifts); outline-first rendering with deliberate sparse interior detail; high contrast against neutral interior backgrounds; dialog framing that respects the player's attention.
- **Scene/screenshot to study:** The host (player) standing at the door console reacting to a visitor — published press shots on Pope's site (https://dukope.com) show this composition. Capture: full-body host sprite at idle, against the apartment interior; observe how the silhouette reads at thumbnail size.
- **HAKCD scene this applies to:** Player sprite (Newb) at 48–64 px target (style guide §2). Newb's idle and walk frames must hit Pope-tier body-language clarity. If the audit's 32×32 smudge is the floor, Pope's host is the ceiling.

---

## Pick Pack Pup

- **Title:** Pick Pack Pup
- **Author:** Nic Magnier (Nic3Niko), 2022 (Season One launch title)
- **Genre:** Match-3 puzzle wrapped in a narrative shop-management frame.
- **Visual specifics worth stealing:** Chunky three-quarter top-down interior compositions; clear foreground/background separation enforced by line weight (background uses thinner lines, foreground props use 2 px); authored tiles (no procedural floor uniformity); UI integrated into the world frame rather than overlaid.
- **Scene/screenshot to study:** Any shop interior scene during a pack sequence. Press kit on the Playdate Catalog (https://play.date/games/pick-pack-pup/) shows the shop in three-quarter view. Capture: full room with player, counter, and customer queue; observe perspective consistency across props.
- **HAKCD scene this applies to:** Both shipped rooms (Bedroom + Playground). Audit §5 documented that both are 17×10 grids with 70% repeated floor tile — Pick Pack Pup is the proof that 3/4 Playdate rooms can be composed without that crutch.

---

## Crankin's Time Travel Adventure

- **Title:** Crankin's Time Travel Adventure
- **Author:** Uvula Inc. (Keita Takahashi + Ryan Mohler), 2022 (Season One launch title)
- **Genre:** Crank-driven side-scrolling timing puzzle.
- **Visual specifics worth stealing:** Crank-as-mechanic visual language — the crank position is the time axis, and the rendering makes that legible (motion blur cues, character pose changes); stylized side-view characters with clear silhouettes against busy backgrounds; restraint with dithering (used only where it serves storytelling, never as a default fill).
- **Scene/screenshot to study:** Any level showing Crankin' moving through environmental hazards. The Playdate launch press kit (https://play.date) shows this clearly. Capture: a single frame mid-traversal; observe how character pose, prop placement, and dither all coordinate to make crank direction obvious.
- **HAKCD scene this applies to:** Lockpick minigame (UI category) and any future crank-driven HAKCD mechanic. Crankin' shows that crank mechanics deserve their own visual idiom — generic "knob spins, thing happens" rendering wastes the input.

---

## Casual Birder

- **Title:** Casual Birder
- **Author:** Diego Garcia, 2022 (Season One launch title)
- **Genre:** Photography exploration / collect-em-up narrative.
- **Visual specifics worth stealing:** Outline-first rendering — every character and prop has a strong 2 px black outline that survives at any zoom; strong silhouettes that work against varied parallax backgrounds (forest, town, rooftop); restrained dithering with most surfaces solid black or solid white, dither reserved for natural textures (foliage, fur).
- **Scene/screenshot to study:** The protagonist (Mo) photographing a bird in a wooded area. Diego Garcia's site (https://diegogarcia.itch.io) carries press shots. Capture: protagonist + bird + foliage in one frame; observe how all three layers stay silhouette-readable.
- **HAKCD scene this applies to:** §4 black-mass rule enforcement across all characters. Casual Birder is the most rigorous Playdate example of "silhouette must communicate identity" — every species of bird in the game is identifiable by silhouette alone.

---

## Saturday Edition

- **Title:** Saturday Edition
- **Author:** Chuhai Labs, 2023
- **Genre:** Detective / point-and-click narrative — Saturday-morning-newspaper aesthetic.
- **Visual specifics worth stealing:** Newspaper aesthetic with **dithering as authored texture language** (every halftone has intent — skin tones, paper, suit fabric all use distinct, deliberately chosen patterns); strong typographic integration (titles and captions feel like newspaper layout); high information density without visual clutter.
- **Scene/screenshot to study:** Any investigation scene with character portraits + dialog. Chuhai Labs press materials (https://chuhailabs.com) show the visual style clearly. Capture: a portrait + speech panel composition; observe the per-surface dither choices.
- **HAKCD scene this applies to:** Style guide §6 (dithering as authored language) and §7 (per-surface pattern catalog). Saturday Edition is the proof that GFXP-style per-surface patterning beats global ordered-dither at every level of scene complexity.

---

## Demon Quest 85

- **Title:** Demon Quest 85
- **Author:** Bardsley Creative, 2023
- **Genre:** Occult RPG / dating-sim hybrid set in 1985.
- **Visual specifics worth stealing:** 80s computer-screen + suburban-apartment aesthetic — tonally adjacent to HAKCD's 1998 phreaker setting; portrait-driven dialog framing with consistent 3/4 perspective character renders; environmental storytelling through prop density without prop *clutter*; UI chrome that looks period-appropriate without being literal pastiche.
- **Scene/screenshot to study:** A dialog scene in the protagonist's apartment with summoning circle visible. Itch.io page (https://bardsleycreative.itch.io/demon-quest-85) carries screenshots. Capture: apartment interior with character + dialog box; observe how the period aesthetic is conveyed by composition + dither + font choice rather than by literal era-specific objects.
- **HAKCD scene this applies to:** Bedroom + Playground rooms (room composition + period mood), portrait rendering for Newb and future NPCs. Demon Quest 85 is the closest sibling — if HAKCD has one mood-twin in the Playdate library, it's this game.

---

**Workflow.** When authoring a new HAKCD asset:

1. Identify which of the six reference games solves the closest problem.
2. Pull a screenshot (or recall the scene) and put it in `docs/reference/games/<game_slug>/`.
3. Write a short `.md` next to it describing the lesson and the HAKCD asset it applies to.
4. Reference that file from the asset's `visual_spec.lua` entry at sign-off (style guide §12).
