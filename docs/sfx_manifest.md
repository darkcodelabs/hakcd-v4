# HAKCD v4 — SFX + Music Manifest

Reproducer for all SFX:

```sh
node tools/audio/synth_v4_sfx.js
```

After (re)generation, optionally re-run the loudnorm pass:

```sh
for f in source/sounds/sfx/*.wav; do
  ffmpeg -y -i "$f" -filter:a loudnorm=I=-16:LRA=11:tp=-1.5 \
    -ar 22050 -ac 1 -sample_fmt s16 "tmp_$(basename "$f")"
  mv "tmp_$(basename "$f")" "$f"
done
```

Music tracks are encoded directly from Bootstrap's normalized 25-track
keygen pool at `assets/sounds/music_masters/sc*.wav` / `title.wav`
(gitignored, kept outside `source/` so pdc doesn't bundle them). Re-encode
recipe is at the bottom of this doc.

## SFX — 14 bespoke (15 wav files)

All synthesized by `tools/audio/synth_v4_sfx.js`. Mono, 22050 Hz, 16-bit PCM.
Target loudness `~-16 LUFS` (ffmpeg `loudnorm I=-16 LRA=11 tp=-1.5`).

Note: ffmpeg `loudnorm` cannot measure clips shorter than ~3 s — many of these
are 25-500 ms one-shots, so the LUFS column shows `n/a` for those. The
loudnorm pass still applies, just without a printed input-LUFS reading.

### Hash-URL parity (sfxr.me)

These are synthesized locally with Node primitives (no browser, no sfxr.me).
The parameter table below documents the synth choices so the audio is
reproducible from this file alone — there are no upstream sfxr hashes to
copy. If a future sprint moves to sfxr.me hash URLs, add the hash next to
each row and keep the synth as the offline fallback.

| Name                       | Premise                                            | Synth (freq / dur / envelope)                                                  | Post-norm LUFS |
|----------------------------|----------------------------------------------------|--------------------------------------------------------------------------------|----------------|
| `lockpick_pin_click_1`     | 30 ms sharp click, brass-tinted noise burst        | noise -> lowpass(0.35) -> expDecay(14); 22050 Hz, 30 ms; amp 0.85              | n/a (short)    |
| `lockpick_pin_click_2`     | Variant 1, slight pitch DOWN                       | as click_1, pitchMul=0.85                                                      | n/a (short)    |
| `lockpick_pin_click_3`     | Variant 1, slight pitch UP                         | as click_1, pitchMul=1.18                                                      | n/a (short)    |
| `lockpick_pin_click_4`     | Variant 1, louder + brighter                       | as click_1, pitchMul=1.05, ampMul=1.18, lowpass(0.6)                           | n/a (short)    |
| `lockpick_pin_set`         | 100 ms confirmation chime                          | square sweep 800 -> 500 Hz, env(0.03, 0.4); amp 0.75                           | n/a (short)    |
| `lockpick_snap`            | 250 ms harsh buzz                                  | square 200 -> 160 Hz + noise (60/40 mix), env(0.02, 0.3); amp 0.9              | n/a (short)    |
| `lockpick_tension_warn`    | 400 ms rising whine                                | square sweep 250 -> 1100 Hz, env(0.05, 0.15); amp 0.7                          | -16.05         |
| `lockpick_open`            | 500 ms — 80 ms thud + 420 ms 4-tone brass arpeggio | thud: sq 110 -> 60 Hz, expDecay(5). arp: 440-554-659-880, 105 ms each, expDecay(6) | -16.05     |
| `tyson_digit_select`       | 25 ms soft tick                                    | noise -> lowpass(0.22) -> expDecay(16); amp 0.55                               | n/a (short)    |
| `tyson_digit_commit`       | 80 ms confirm beep                                 | square 850 Hz, env(0.02, 0.5); amp 0.65                                        | n/a (short)    |
| `tyson_winner`             | 680 ms Punch-Out WINNER homage                     | 4x 120 ms arp C5(523)-E5(659)-G5(784)-C6(1047) + 200 ms sustained C-E-G triad  | -15.97         |
| `coin_navigate_tick`       | 22 ms soft click-wheel tick                        | noise -> lowpass(0.5) -> expDecay(18); amp 0.55                                | n/a (short)    |
| `coin_zoom_whoosh`         | 220 ms band-passed noise whoosh                    | noise -> lp(0.18) - lp(0.03) (band-pass), env(0.5, 0.4); amp 0.8               | n/a (short)    |
| `coin_mint`                | 350 ms sparkle chime, brighter than tyson_winner   | square sweep 200 -> 2200 Hz + shimmer 400 -> 4400 Hz, expDecay(4); amp 0.8     | n/a (short)    |
| `pwnglove_boot`            | 500 ms C major triad with slight rise              | sq 261 -> 280 + 329 -> 352 + 392 -> 420 Hz mix, env(0.05, 0.4); amp 0.75       | -16.07         |

## Music — 5 picks from 25 keygen tracks

All re-encoded mono 44.1 kHz `pcm_s16le`, capped at 3 minutes, 1 s fade-in
and 2 s fade-out for loop-friendly seams. Target loudness -14 LUFS (the
Bootstrap normalization already brought the source pool into the ±3 dB
acceptance window per `tools/audio/keygen_loudness_baseline.txt`).

| Manifest name       | Source track (Bootstrap's normalized pool)       | Duration | Final LUFS |
|---------------------|--------------------------------------------------|----------|------------|
| `title_loop`        | `title.wav`                                      | 180.0 s  | -14.69     |
| `bedroom_loop`      | `sc01_bedroom_recurring_hub.wav`                 | 180.0 s  | -16.99     |
| `playground_loop`   | `sc04_corporate_bbs_phoenixdown.wav`             | 179.2 s  | -16.36     |
| `tyson_loop`        | `sc10_phreakkingdom.wav`                         |  89.4 s  | -15.31     |
| `coinvault_loop`    | `sc23_release_decision_scene.wav`                | 134.2 s  | -15.07     |

All five LUFS readings sit inside the -17 to -11 acceptance window.

## Scene wiring

`source/sounds/manifest.lua` exposes:

- `sound_manifest.play_sfx(name)` — one-shot SFX by manifest name. Variant
  lists (currently only `lockpick_pin_click`) are resolved randomly per call.
  Unknown names no-op silently so scene code doesn't have to guard.
- `sound_manifest.music_for(scene_name)` — returns a `fileplayer` configured
  to loop, or `nil` if the scene is silent (LockpickScene) or unknown.

Scene -> music wiring:

| Scene             | Track            |
|-------------------|------------------|
| `TitleScene`      | `title_loop`     |
| `BedroomScene`    | `bedroom_loop`   |
| `PlaygroundScene` | `playground_loop`|
| `LockpickScene`   | (silent)         |
| `TysonScene`      | `tyson_loop`     |
| `CoinVaultScene`  | `coinvault_loop` |

## Music re-encode recipe

```sh
ffmpeg -y -i assets/sounds/music_masters/<src>.wav -t <out_dur_seconds> \
  -filter:a "afade=t=in:st=0:d=1,afade=t=out:st=$((out_dur-2)):d=2" \
  -ar 44100 -ac 1 -sample_fmt s16 -c:a pcm_s16le \
  source/sounds/music/<dest>_loop.wav
```

Re-pick a track by editing `source/sounds/manifest.lua`'s `music_for_scene`
table and re-encoding from the corresponding master `sc*.wav`.
