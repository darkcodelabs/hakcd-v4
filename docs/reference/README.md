# HAKCD Reference Library

Purpose: this directory holds **reference imagery for every visual asset** that ships in HAKCD. The style guide (`docs/style_guide.md`) is the *rules*; this directory is the *examples*. Every asset claiming `art_status='final'` (per §12 of the style guide) must have a reference file here.

## Structure

```
docs/reference/
  characters/   — per-character reference (NPC look, pose, attitude)
  rooms/        — per-room reference (composition, depth, mood)
  ui/           — per-UI-element reference (lockpick, coin vault, Tyson cabinet, etc.)
  palettes/     — dither pattern usage examples (GFXP catalog samples)
  games/        — reference-game screenshots (Mars After Midnight, Pick Pack Pup, etc.) for direct comparison
```

Each subdirectory is created with a `.gitkeep` placeholder. As reference imagery lands, the `.gitkeep` stays.

## Naming

- Reference files: `<asset_id>_<variant>.png` or `<asset_id>_<variant>.md`
  - Examples: `newb_idle_south.png`, `playground_overview_3q.png`, `lockpick_pope_ref.png`
  - `asset_id` matches the id used in `source/data/assets.lua` whenever possible
  - `variant` describes which aspect this reference captures (`idle`, `walk`, `overview`, `silhouette`, `palette`, etc.)
- Pairing: every reference file should have a `.md` sibling describing **what aspect of the reference is the target**.
  - Example: `newb_idle_south.png` + `newb_idle_south.md` (md explains "silhouette readability + 2px outline + hood/shoulder/feet articulation are the target; ignore the background color")
- `.md`-only entries are allowed when the reference is a published commercial screenshot we cannot redistribute. The `.md` describes the source (game, scene, timestamp) and what to mimic.

## Categories — what belongs where

**`characters/`** — Reference for player + NPC sprites. One subdirectory per character id when references multiply.
- Player: `newb/` (idle 4-direction + walk 4-direction + interact + surprised)
- NPCs: `<npc_id>/` per named character as they're authored

**`rooms/`** — Reference for level composition. One file (or subdirectory) per room id.
- `bedroom/` — Newb's bedroom; reference shows 3/4 composition, prop hierarchy, perspective lines
- `playground/` — PWNGLOVE Mode arcade; reference shows station differentiation, neon hierarchy, depth
- Future rooms get one entry as they're added to `source/data/rooms.lua`

**`ui/`** — Reference for HUD and interactive UI elements.
- `lockpick/` — Lucas Pope `lockpickmini` references for the lockpick minigame
- `coin_vault/` — coin grid layout, coin states, locked-coin treatment
- `dialog_box/` — dialog framing, font choice, text density
- `tyson_cabinet/` — arcade cabinet rendering (the gameplay context for §4's "cabinet-vs-server-rack" silhouette rule)

**`palettes/`** — Reference for dither pattern application, mapped to §7 of the style guide.
- One file per (surface, pattern) pair: e.g., `wood_floor_dot-3.png`, `brick_wall_brick-1.png`
- Shows the pattern applied to a representative surface at the actual size it will render in-game

**`games/`** — Screenshots from the six reference games (`docs/reference/playdate_reference_games.md`).
- Subdirectories: `mars_after_midnight/`, `pick_pack_pup/`, `crankin/`, `casual_birder/`, `saturday_edition/`, `demon_quest_85/`
- Each subdirectory has `.md` files describing what scene the screenshot is from + the lesson it teaches
- Screenshots themselves may need to live external to git (commercial redistribution); `.md` entries link or describe

## Workflow

1. **Before** authoring a new asset: create or locate its reference file in this directory.
2. **During** authoring: open the reference alongside the asset.
3. **At sign-off** (per style guide §12): the reference path is recorded in the asset's `visual_spec.lua` entry. No reference, no `art_status='final'`.

Phase V4–V8 (per the recovery plan) will populate this directory with concrete reference imagery as each asset class lands. V1 ships the scaffolding only — the discipline starts here.
