# HAKCD Visual Style Guide

Phase V1 — v0.1.28. Sacred document. Every visual asset in this game is gated by these rules. If an asset does not satisfy them, it does not ship — no matter how cleanly it validates.

---

## 1. Purpose

This guide is the **visual contract** for HAKCD. The canon-first architecture (v0.1.20–v0.1.27) succeeded at locking the data graph, the id resolver, and the build pipeline — but it left a hole where the art bar should have been. The `VISUAL_PIPELINE_FAILURE_AUDIT.md` (v0.1.27) documents the consequence: the validator is "theatrical" — it confirms 21/21 PNGs are 1-bit grayscale with detectable outlines, which is true and useless. Procedural primitives, lossy concept downscales, and uniformly-tiled carpet rooms all passed it. They will not pass this guide.

Every PNG that ships in `source/images/**` must be authored or curated against the rules in §§2–10. Every asset that claims `art_status='final'` in `source/data/assets.lua` must satisfy §12 (sign-off). This document is the source of truth; the audit was the diagnosis, and this is the prescription.

---

## 2. Character Scale

The audit found Newb shipping at **32×32**, which produces a vertical smudge with no head/body/limb articulation at hardware viewing distance. That target is wrong for HAKCD's required readability.

**Targets**

| Character type | Minimum | Preferred | Notes |
|---|---|---|---|
| Player protagonist (Newb) | 48×48 | **64×64** | Suburban hacker silhouette must read as a person, not as a map marker. Hood, shoulders, and feet must each occupy ≥ 4px of clearly authored mass. |
| Major NPC (named, recurring) | 48×48 | 64×64 | Same readability standard as player. |
| Minor NPC (background, ambient) | 32×48 | 48×48 | Pose silhouette must distinguish from player at a glance. |
| World object (cabinet, CRT, bed) | 48×48 | tile-grid composite (24×24 × N) | Multi-tile composites preferred over single oversized sprite. |
| UI icon (HUD, inventory) | 16×16 | 24×24 | Outline-first; no internal dither at this size. |

**Rationale.** Donald Hays's "Playdate Art: Scale" rule (32×32 for floor characters) presumes hand-pixel authoring at the target resolution. HAKCD's protagonist is a hooded human in a 1998-suburban setting, not an abstract platformer mascot — that subject matter requires more articulation than 32 pixels affords.

**Hardware-readability check.** At 400×240 native, the player sprite **must occupy ≥ 15% of vertical height** (≥ 36 px). A 32×32 sprite at 13% fails; a 48×48 at 20% passes; a 64×64 at 27% is preferred. Measure on actual device, not simulator.

---

## 3. Perspective

**Locked in for HAKCD: three-quarter top-down.** No exceptions, no mixing within a scene.

- Camera angle: ~30° downward tilt, viewer slightly elevated and offset.
- Floor tiles render as parallelograms suggesting depth; props render with visible top + front face (no pure profile, no pure overhead).
- Reference: Pick Pack Pup (room interiors), Demon Quest 85 (apartment scenes). Both ship coherent 3/4 worlds where every prop reads at the same angle.

**Vanishing-point consistency rule.** Every prop in a room aligns to the same 3/4 angle. A bed and a CRT in the same room cannot face different "camera-down" directions. If you can't fit a prop into the 3/4 grid, redraw the prop — do not rotate the camera.

**Banned within a scene:** mixing perspectives (e.g., a top-down floor with a side-view prop). Mixing reads as a different game in every frame. The audit's Bedroom and Playground rooms both fail this implicitly because their props are silhouette stamps with no consistent perspective at all — they read as flat decals on a carpet.

---

## 4. Black Mass Rule

Every sprite must read in **pure silhouette**. At 1-bit, **black mass > detail, outline > texture, shape > dithering**.

**Silhouette readability test.** Fill the sprite solid black on a white background and show it alongside the rendered version. The pure-black version must communicate identity: "that is a Newb," "that is a CRT," "that is a Tyson cabinet." If the silhouette reads as a generic blob, the sprite fails — no amount of internal detail rescues it at hardware scale.

**Anti-pattern (Pope's "cabinet-vs-server-rack").** Two distinct gameplay objects must not share a silhouette. If the arcade cabinet and the server rack both pure-black to a vertical box with a square notch, the player cannot distinguish them at glance distance. One of them gets a distinguishing silhouette feature (e.g., the cabinet gets a marquee bulge, the server rack gets a vented top).

The Newb 32×32 imagetable failed this test in the audit (§4 of the audit doc): every direction silhouettes to a vertical smudge with a head-bulge. Replacement art must pass the test from every cardinal direction before any `art_status='final'` claim.

---

## 5. Line Weight

- **2-pixel outlines on every object boundary.** Sprite-vs-world, sprite-vs-sprite, prop-vs-floor — all 2px black.
- **1-pixel for internal detail lines.** Folds in clothing, edges of buttons, lines on a CRT. 1px is the floor; nothing finer ships.
- **No sub-pixel features.** Anything authored as < 1px (e.g., a hairline produced by mechanical anti-aliasing or filter blur) is invisible on hardware. Do not author it.
- **Outlines must be hand-authored, not added mechanically.** ImageMagick morphology (`-morphology EdgeOut`) tacks an outline onto whatever silhouette already exists — it does not produce design-intentional outlines. Hand-pixel the outline pass.

---

## 6. Dithering Rules

Dithering in HAKCD is an **authored texture language**, not a conversion step.

**FORBIDDEN.** Global `-ordered-dither o4x4 -monochrome` as an output filter. This is the audit's root cause #2 (lossy concept downscale) and root cause #5 (procedural tileset). It eats outlines, destroys figure/ground separation at small scale, and replaces designer intent with deterministic noise.

**ALLOWED.** Per-surface dither patterns chosen with design intent. The Playdate community library `GFXP` exposes 136 named patterns; each surface type in HAKCD has a designated pattern (catalog in §7). Apply only when the surface has a known material identity (wood, brick, glow, shadow). Never apply as a "convert to 1-bit" pass.

**Rule of thumb.** If you can't name the surface (e.g., "this is a wood floor in the bedroom"), you can't dither it. Solid black or solid white is always safer than wrong-pattern dither.

---

## 7. Dither Pattern Catalog (HAKCD-specific)

Designated patterns per surface type. New surfaces require a catalog entry before they ship.

| Surface | Pattern | Use |
|---|---|---|
| Wood floor (bedroom) | `gray-50` or `dot-3` | Tonal floor; reads as midtone wood, not as carpet. |
| Carpet (playground) | `vert-2` | Linear weave; distinguishes from wood. |
| Brick wall | `brick-1` | Literal brick — pattern *is* the material. |
| CRT glow | `dot-7` | Bright noise; suggests scanline aura on phosphor. |
| Shadow (under prop) | `dot-1` | Sparse dot; suggests soft cast shadow without solid black. |
| Concrete (playground exterior) | `noise` | Irregular; reads as poured surface. |
| Sky (rare — most HAKCD is interior) | `vert-1` | Vertical fade for the few outdoor moments. |

Pattern names follow GFXP convention. Implementation: applied at room-composition time as `playdate.graphics.setPattern(GFXP.pattern[name])` before drawing the surface tile — not baked into the PNG.

---

## 8. UI Placement

UI in HAKCD is **chunky, readable, tactile**. The Playdate has no touch input, but visual chunkiness equivalent to a 16-pixel tap target is the design floor.

- **Dialog boxes:** 60 px tall minimum, bottom-anchored. Full 400 px width. 2 px outline (rule §5). Inset 6 px from the screen edge to leave visual breathing room.
- **HUD:** top-right OR top-left, never both — never center. Center belongs to gameplay. A small HUD element in one top corner is canonical; competing HUDs in both corners is banned.
- **Text:** Playdate's native 8 px font is the absolute minimum (system menus only). 16 px preferred for in-game dialog. Hand-author kerning if the system font produces ambiguous letter pairs.
- **Interactive prompts (button hints):** 24×24 icon + 16 px label. Always positioned adjacent to the actionable object, never floating mid-screen.

---

## 9. Playdate Hardware Readability

The **only** acceptable readability bar is real-device, arm's-length viewing distance.

- Test target: actual Playdate hardware, 30–40 cm viewing distance, ambient indoor light. Simulator-only review does not count.
- Any asset that requires squinting fails. Squinting includes "I can tell what it is because I authored it" — that's not readability, that's familiarity.
- **Per-asset readability test:** take a simulator screenshot, resize to actual device pixel-per-mm (Playdate is 173 ppi on a 2.7" screen → ~6.8 px/mm; print at that physical scale and view from 35 cm). If you cannot identify the asset, redo it.
- **Sideload-and-photograph workflow mandatory** before any `art_status='final'` claim. Sideload to a real device, take a photograph of the screen (not a simulator screenshot), check the photograph at viewing distance. The photo lives in `tools/hardware_review/<version>/<asset_id>.jpg` (Phase V9 owns the workflow).

The audit found 0 assets in the build had ever been photographed on real hardware. That changes here.

---

## 10. Banned Methods (from Audit Root Cause #1)

For **gameplay-facing assets** — anything in `source/images/sprites/`, `source/images/portraits/`, `source/images/tilesets/`, `source/images/scenes/`, `source/images/ui/`, and `source/levels/**`:

1. **ImageMagick primitive draw commands.** `convert -draw "rectangle ..."`, `-draw "circle ..."`, etc. Procedural primitives are not pixel art; they are vector approximations dithered down to 1-bit.
2. **Concept-art auto-shrink.** `-resize WxH^ -filter point` on concept renders larger than 2× the target. Lossy. Eats sub-cell detail. The Newb 32×32 imagetable was generated from 100×60 concept cells via this exact command and is unreadable.
3. **Global `-ordered-dither o4x4 -monochrome` as final pass.** See §6. This destroys figure/ground separation and is the dither equivalent of "I gave up on this asset."
4. **Text-label baking.** `convert ... -draw "text 0,0 'LABEL'"` to bake words ("MIKE TYSON", "INSERT COIN") onto sprites. Text in sprites does not localize, does not scale, and produces unreadable smear at hardware size.

**Allowed only for:** debug visuals, internal tools, test fixtures, build-time silhouette dumps (`build/silhouettes/`). Any procedural output in those directories is fine; any procedural output in `source/images/**` is a build break, gated by Phase V3 (rule 10 enforcer).

---

## 11. Reference Game Targets

The visual bar for HAKCD is set by these six Playdate titles. Full per-game breakdown in `docs/reference/playdate_reference_games.md`; one-line takeaways here:

- **Mars After Midnight** — hand-pixel character, expressive body language, ~64-tall protagonist. Sets the player-sprite bar.
- **Pick Pack Pup** — chunky 3/4 perspective rooms, clear FG/BG, authored tiles. Sets the room-composition bar.
- **Crankin's Time Travel Adventure** — crank-as-mechanic visual language; mechanic and rendering co-designed. Sets the input-affordance bar.
- **Casual Birder** — outline-first rendering, strong silhouettes against varied backgrounds. Sets the §4 black-mass bar.
- **Saturday Edition** — newspaper aesthetic, dithering as authored texture (every halftone has intent). Sets the §6 dither bar.
- **Demon Quest 85** — 80s computer-screen aesthetic adjacent to HAKCD's 1998 suburbia. Closest tonal sibling; sets the room-mood bar.

---

## 12. Acceptance / Sign-off

Every asset claiming `art_status='final'` in `source/data/assets.lua` must satisfy **all three**:

1. **Reference image present.** A file lives at `docs/reference/<category>/<asset_id>.png` (or `.md` describing the source if the reference is a published game screenshot we don't redistribute). Categories: `characters/`, `rooms/`, `ui/`, `palettes/`, `games/`. See `docs/reference/README.md` for layout.
2. **Reviewer handle + ISO date.** Recorded in the asset's `visual_spec.lua` entry. Phase V2 owns the `visual_spec.lua` schema; until V2 ships, record reviewer + date as a comment in `source/data/assets.lua` next to the asset entry.
3. **Hardware photo capture.** Photograph of the asset rendered on real Playdate hardware, filed at `tools/hardware_review/<version>/<asset_id>.jpg`. Phase V9 owns the capture workflow and the verifier.

An asset that satisfies the build validator but fails any of the above is `art_status='placeholder'` regardless of how complete it appears. The build does not gate on this today; reviewer discipline does. Phase V2+ will incrementally make these checks validator-enforced.

---

**End of style guide.** Next edits to this document are scoped to Phase V2 (visual_spec schema), V3 (banned-method enforcer integration), and V9 (hardware-review verifier integration). Edits outside those phases require a recovery-plan amendment.
