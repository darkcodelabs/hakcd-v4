#!/usr/bin/env bash
# tools/sprites/build_newb_from_concept.sh
# Build source/images/newb-table-32-32.png from docs/concepts/newb_sprite_sheet.png.
#
# Concept sheet is 400x240 with a 4-col x 4-row grid of 100x60 cells:
#   Row 1: north walk cycle (4 frames)
#   Row 2: south walk cycle (4 frames)
#   Row 3: east walk cycle (4 frames)
#   Row 4: head close-ups (3 used for interact/surprised, 1 unused)
# East frames mirror to west via -flop. Result: 28-cell 4x7 imagetable
# matching AnimatedSprite naming convention `<name>-table-<W>-<H>.png`.

set -euo pipefail

SRC="${1:-docs/concepts/newb_sprite_sheet.png}"
OUT="${2:-source/images/newb-table-32-32.png}"

work=$(mktemp -d)
trap "rm -rf $work" EXIT

# Slice 4x4 grid into 16 cells
convert "$SRC" -crop 100x60 +repage "$work/cell_%02d.png"

# Downscale each cell to 32x32, 1-bit dithered
for i in 00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15; do
  convert "$work/cell_$i.png" \
    -resize 32x32 -gravity center -extent 32x32 \
    -background white -alpha remove -filter point \
    -ordered-dither o4x4 -monochrome \
    "$work/n$i.png"
done

# Blank cell + west mirrors
convert -size 32x32 xc:white "$work/blank.png"
for i in 08 09 10 11; do
  convert "$work/n$i.png" -flop "$work/n${i}_flop.png"
done

# Frame layout (AnimatedSprite spec):
#   1-2   idle_south  (cell 04 dup for breathing fallback)
#   3-6   walk_south  (cells 04 05 06 07)
#   7     idle_north  (cell 00)
#   8-11  walk_north  (cells 00 01 02 03)
#   12    blank
#   13    idle_east   (cell 08)
#   14-17 walk_east   (cells 08 09 10 11)
#   18    blank
#   19    idle_west   (cell 08 flopped)
#   20-23 walk_west   (cells 08-11 flopped)
#   24    blank
#   25    interact    (cell 05 — south w/ leg extension)
#   26    surprised   (cell 12 — first head close-up)
#   27-28 blank
montage \
  "$work/n04.png" "$work/n04.png" "$work/n04.png" "$work/n05.png" \
  "$work/n06.png" "$work/n07.png" "$work/n00.png" "$work/n00.png" \
  "$work/n01.png" "$work/n02.png" "$work/n03.png" "$work/blank.png" \
  "$work/n08.png" "$work/n08.png" "$work/n09.png" "$work/n10.png" \
  "$work/n11.png" "$work/blank.png" "$work/n08_flop.png" "$work/n08_flop.png" \
  "$work/n09_flop.png" "$work/n10_flop.png" "$work/n11_flop.png" "$work/blank.png" \
  "$work/n05.png" "$work/n12.png" "$work/blank.png" "$work/blank.png" \
  -tile 4x7 -geometry 32x32+0+0 -background white "$work/_montage.png"

convert "$work/_montage.png" \
  -ordered-dither o4x4 -monochrome \
  -define png:bit-depth=1 -define png:color-type=0 \
  "$OUT"

echo "Wrote $OUT"
file "$OUT"
