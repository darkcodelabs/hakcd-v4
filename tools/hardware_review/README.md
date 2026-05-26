# Hardware Review Workflow

Sideload -> screenshot -> device photo -> human signoff loop. Every visual asset
that claims `art_status='final'` in `source/data/visual_spec.lua` (Phase V2)
MUST pass through this workflow before it is allowed to ship.

This is the gate. The validator (Phase V3) will eventually enforce it. Until
v0.2.0 lands, the validator warns but does not fail — that gives infrastructure
(the spec, this workflow, the script) time to land before final art does.

---

## Section 1: Workflow overview

1. **Build .pdx**

   ```
   make all
   ```

   Confirm `HAKCD.pdx` produced cleanly with no validator failures.

2. **Sideload to device OR launch in Simulator**

   - Device: copy `HAKCD.pdx` to the Playdate over USB (Data Disk mode) into
     `/Games/HAKCD.pdx`. Eject. Launch from device menu.
   - Simulator: `open HAKCD.pdx` on macOS, or `PlaydateSimulator HAKCD.pdx` on
     Linux from `~/PlaydateSDK/bin/`.

3. **Capture Simulator screenshots**

   ```
   ./tools/hardware_review/capture_screenshots.sh \
       HAKCD.pdx \
       tools/hardware_review/v0.1.X/simulator/
   ```

   Or run the manual capture protocol the script prints (Linux fallback).

4. **Take hardware photographs**

   Device + finger for scale, arm's length, well-lit, no flash glare. One photo
   per critical scene. Save to `tools/hardware_review/v0.1.X/device/`.

5. **Compare against reference imagery**

   Side-by-side against `docs/reference/<scene>/` (the canonical reference set
   owned by Phase V1). Look for: composition drift, readability at arm's length,
   placeholder leaks, missing UI affordances.

6. **Sign off**

   Copy `per_version_template.md` into `tools/hardware_review/v0.1.X/SIGNOFF.md`
   and fill out:
   - Reviewer handle
   - ISO date (YYYY-MM-DD)
   - Build commit SHA
   - Per-asset PASS/FAIL/WIP verdict
   - Freeform notes in `review_notes.md`

---

## Section 2: Directory layout

```
tools/hardware_review/
  README.md                        — this file
  capture_screenshots.sh           — Simulator capture driver
  per_version_template.md          — copy this for each release
  v0.1.X/
    simulator/                     — Simulator screenshots (one per scene)
    device/                        — phone-camera shots of real Playdate
    SIGNOFF.md                     — per-asset PASS/FAIL/WIP table + reviewer + date
    review_notes.md                — freeform comments
```

One `v0.1.X/` directory per release that ships visual changes. Earlier
directories are kept as the historical record — they are what we point at when
asking "did we ever sign this off, and who, when, on what build."

---

## Section 3: `capture_screenshots.sh` usage

```
./tools/hardware_review/capture_screenshots.sh <pdx_path> <output_dir>
```

The script attempts to drive the Playdate Simulator and save one PNG per scene.
The Playdate Simulator is Mac-primary; on Linux, scriptable capture is not
exposed by SDK 3.0.6, so the script falls back to printing the manual capture
protocol for the human operator.

### Scenes captured per session (matches `canon.scenes`)

Nine screenshots minimum per signoff:

1. `TitleScene`
2. `BedroomScene`
3. `ComputerScene` (modal)
4. `ModemScene` (modal)
5. `PhoneScene` (modal)
6. `PlaygroundScene`
7. `LockpickScene` (minigame)
8. `TysonScene` (minigame, with code partially entered)
9. `CoinVaultScene` (grid view + closeup of coin 0)

Naming: `<scene_name>.png` for Simulator, `<scene_name>_arm.jpg` for device.

### Manual capture protocol (Mac)

1. Open Playdate Simulator.
2. File > Open > `<pdx_path>`.
3. For each scene above, navigate via gameplay.
4. File > Save Screen... (or Cmd+Shift+4 on the Simulator window).
5. Save with the naming convention into `<output_dir>/`.

### Manual capture protocol (Linux)

1. Launch `~/PlaydateSDK/bin/PlaydateSimulator <pdx_path>`.
2. For each scene, navigate via keyboard input mapped to Playdate buttons.
3. Use the system screenshot tool (`gnome-screenshot -w`, `flameshot gui`, etc.)
   to grab the Simulator window.
4. Save with the naming convention into `<output_dir>/`.

---

## Section 4: Hardware photograph requirements

The screenshot tells you what the renderer produced. The device photo tells you
what a human eye actually sees on the panel from typical play distance. Both
matter; the panel + ambient light + 1-bit dither interact differently from how
the Simulator pretends.

Requirements:

- **Distance:** device held at arm's length (~50cm), the typical play distance.
- **Camera:** phone camera, well-lit room, no direct flash on the screen
  (causes glare bands that mask real readability).
- **Scale reference:** include a finger or thumb in-frame to anchor scale.
- **Coverage:** one photo per critical scene — same scenes as the Simulator
  capture list above.
- **Path:** `tools/hardware_review/v0.1.X/device/<scene_name>_arm.jpg`.

If a critical asset reads on Simulator but mushes into a grey blob on hardware
at arm's length, that is a **FAIL**, not a PASS. The hardware is the ground
truth.

---

## Section 5: Per-asset PASS/FAIL/WIP rubric

For each asset listed in `source/data/visual_spec.lua` (Phase V2):

- **PASS** — looks intentional. Reads clearly at arm's length on hardware.
  Matches the reference imagery in `docs/reference/<scene>/`. No placeholder
  artifacts (stick figures, wireframe boxes, raw text on blank, "PLACEHOLDER"
  watermarks, wax-melted thumbprint shapes).

- **FAIL** — placeholder still in shipping build, unreadable at arm's length,
  compositional fail (subject cropped, focal point lost in dither, illegible
  silhouette), or drifts visibly from the reference. Blocks release of any
  asset claiming `art_status='final'`.

- **WIP** — known-incomplete, intentional, signed off as in-progress with a
  target version for completion noted in the SIGNOFF.md row. Acceptable for
  non-critical assets only; critical assets cannot be WIP at release time.

---

## Section 6: Signoff blocking rule

Per the recovery plan Phase V10 (v0.2.0):

Once **all three** of these are true:

- `source/data/visual_spec.lua` exists (Phase V2)
- `tools/asset_validator.sh` checks `human_reviewed` and `art_status` (Phase V3)
- pdxinfo version >= 0.2.0

...the build FAILS if **any** asset with `priority='critical'` has either:

- `human_reviewed != true`, OR
- `art_status == 'placeholder'`

Until v0.2.0, the validator emits warnings only. That window exists so the
infrastructure (this workflow, the spec, the validator) can land before art
production catches up. It is not a window to ship placeholder art with a
`final` label — that lie is exactly what this workflow exists to catch.

Signoff is by human handle, dated, against a specific commit SHA, with the
Simulator screenshot AND device photo both checked in. No screenshots, no
signoff. No signoff, no `art_status='final'`. No `final`, no release.
