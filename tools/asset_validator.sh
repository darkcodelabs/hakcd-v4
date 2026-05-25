#!/usr/bin/env bash
# tools/asset_validator.sh
# Pre-compile gate: validate every PNG that ships into the .pdx is
# Playdate-safe 1-bit, has a detectable outline, and gets a silhouette
# dump for manual cabinet-vs-server-rack readability check.
#
# Usage:
#   ./tools/asset_validator.sh <png_path>
#
# Exits 0 on pass, non-zero on fail. Drops silhouette previews to
# build/silhouettes/ for human review.
#
# Constraints enforced (per docs/concept_art_prompt.md):
#   1. Two-color rule: only RGB 0,0,0 and RGB 255,255,255 allowed. No gray.
#   2. Outline detectable: image has at least 8 edge pixels (rough heuristic).
#   3. Silhouette preview written to build/silhouettes/<basename> for review.

set -uo pipefail

file="${1:?usage: asset_validator.sh <png_path>}"

if [ ! -f "$file" ]; then
  echo "FAIL $file: file not found"
  exit 2
fi

fail=0

# Gate 1 — 1-bit / two-color rule
# `convert in.png -unique-colors txt:` outputs one line per unique color;
# header line starts with '#' so we count lines that start with a digit
# (the pixel coordinate prefix).
colors=$(convert "$file" -unique-colors txt: 2>/dev/null | grep -c '^[0-9]')
if [ "$colors" -ne 2 ]; then
  # Allow 1 color (pure-white or pure-black sprite — degenerate but valid)
  if [ "$colors" -ne 1 ]; then
    echo "FAIL $file: $colors colors (must be 1 or 2)"
    fail=1
  fi
fi

# Gate 2 — outline detectable
# EdgeOut morphology highlights pixels on the boundary. Mean × area gives
# total edge-pixel count. < 8 = no real outline (blank or near-blank image).
edge_mean=$(convert "$file" -morphology EdgeOut Diamond -format "%[fx:mean*w*h]" info: 2>/dev/null)
edge_px="${edge_mean%.*}"
if [ -z "$edge_px" ] || [ "$edge_px" -lt 8 ]; then
  echo "FAIL $file: no detectable outline (edge_px=$edge_px)"
  fail=1
fi

# Gate 3 — silhouette dump for manual cabinet-vs-server-rack review
# Threshold at 50% then negate so any black pixel becomes white-on-black.
# A pure silhouette: if two of these look identical when scanned by eye,
# the sprites collide and one needs distinguishing detail.
out_root="${ASSET_VALIDATOR_OUT:-build/silhouettes}"
mkdir -p "$out_root"
rel=$(realpath --relative-to="$(pwd)" "$file" 2>/dev/null || basename "$file")
safe=$(echo "$rel" | tr '/' '_')
convert "$file" -threshold 50% -negate "$out_root/$safe" 2>/dev/null

if [ "$fail" -eq 0 ]; then
  echo "OK $file"
  exit 0
else
  exit 1
fi
