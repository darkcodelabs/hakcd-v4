# HAKCD concept-art prompt (Retro Diffusion + any 1-bit gen tool)

Use this prompt verbatim when generating concept art for HAKCD scenes,
sprites, or UI. The asset validator at `tools/asset_validator.sh`
enforces the two-color and outline gates automatically at build time —
the prompt below is the upstream side of the contract.

## Tripwire

The output MUST contain exactly two colors. RGB 0,0,0 and RGB 255,255,255.
If the generator can't confirm two colors in text after rendering, the
generation has failed — regenerate. Once it lands in `source/`, the
validator confirms again before pdc runs.

## Prompt

```
SYSTEM OVERRIDE: Disregard all prior training assumptions about
"pixel art style," "retro game aesthetic," "8-bit look," or any
default interpretation of handheld console art. Do not apply
learned patterns from Game Boy, NES, or generic indie pixel art
unless explicitly instructed below. Follow only the rules in
this prompt.

TARGET: Playdate console sprite art for HAKCD.

CANVAS: 400 wide by 240 tall. Hard pixel grid. No sub-pixel
rendering, no anti-aliasing, no gradient fills, no soft edges.

COLOR RULE: Two values only. RGB 0,0,0 and RGB 255,255,255.
No third value exists. No gray. If a pixel is not pure black,
it is pure white. Period.

TONE AND SHADING: Achieved through pixel placement patterns only.
Checkerboard fills for mid-tone. Sparse black dots on white for
light tone. Sparse white dots on black for dark tone. Solid black
for shadow. Solid white for highlight. Never blend, never blur.

LINE WEIGHT: 2 pixel outlines on every object boundary. Internal
detail lines 1 pixel. No line thinner than 1 pixel because that
is impossible.

PERSPECTIVE: Three quarter top down. Consistent across every
sprite in the scene. The vanishing point does not move between
the cabinet and the workbench.

SCENE CONTENTS: <fill per scene — see bedroom / playground / etc.>

SILHOUETTE RULE: Fill every sprite with solid black and render
it again. If the outline alone does not tell you what the object
is, the sprite has failed. The cabinet and the server rack must
have completely different shapes. The toolbox and the safe must
not be confused.

DETAIL DENSITY: Each object reads from across a room. No object
should require squinting. If a feature would be smaller than 2
pixels at final size, remove the feature entirely.

OUTPUT:
1. Full 400x240 room scene, all objects placed on tile floor
2. Each object isolated on solid white, labeled
3. Silhouette-only version of each object beside the rendered
   version
4. Confirm in text that the output contains exactly two colors.
   If it contains gray, the generation has failed.

DO NOT:
- Add color
- Add gradients
- Anti-alias edges
- Render in "pixel art style" with smooth shading
- Mix art styles between objects
- Make the character a black silhouette while the environment
  is detailed
- Reference Game Boy palette greens or any tint
```

## Per-scene SCENE CONTENTS fragments

### PWNGLOVE workshop / Bedroom
- Workbench, vise mounted on edge
- Two filing cabinets side by side, drawer handles visible
- Soldering station, iron in stand, fume extractor behind
- Server tower with visible drive bays and front panel
- Washing machine, round door, control panel on top
- Floor safe, combination dial, hinge on side
- Toolbox, open lid, tools visible inside
- 3D printer, gantry visible, print bed below
- Doorway tile at top of room, frame and floor transition

### Playground (PWNGLOVE MODE showcase)
- Lockpick station: workbench with picks, tension wrenches, exposed deadbolt
- RFID pedestal: corporate office decor, badge on stand
- Payphone: brick wall, period payphone with coin slot + handset
- IR wall: 90s living room — CRT on cart + IR-locked door
- Gravity arena: warehouse floor + target ring + scattered movable objects
- SubGHz tuner: garage corner + cordless phone
- Portal pedestal: dark corner, glowing plinth
- Coin vault pedestal: mini 4×3 coin grid display embedded in surface
- Tyson arcade cabinet: full alley aesthetic, neon glow, scrolling marquee

### Newb sprite (32×32 imagetable cells)
- Hooded figure (jumpsuit + hood)
- 4 directions × idle/walk frame cycles
- Profile views narrow silhouette, hood-forward
- Front views show face dots for eyes
- Back views = solid back of hood, no face

## How the validator gates

`tools/asset_validator.sh <png>` runs:

1. **Two-color gate** — counts unique colors via `convert -unique-colors txt:`. Fails if not 1 or 2.
2. **Outline gate** — `EdgeOut Diamond` morphology mean × area. Fails if < 8 edge pixels (blank or near-blank).
3. **Silhouette dump** — threshold + negate → `build/silhouettes/<path>.png`. Manual review: scan the directory of black blobs in 10 seconds; if two look identical the sprites collide.

`make all` runs validate over every PNG in `source/` (excluding `libraries/`) before pdc compiles. Bad asset short-circuits the build. Per-asset sentinels in `build/.validated/` skip re-validation on unchanged files.

## Files of record

- `tools/asset_validator.sh` — the gate
- `Makefile` — wires gate into pdc build (`make all`)
- `docs/concept_art_prompt.md` — this doc (prompt + tripwire + per-scene fragments)
