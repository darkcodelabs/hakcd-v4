#!/usr/bin/env bash
# build_newb.sh — procedural builder for the newb hooded-silhouette imagetable.
#
# Output:
#   source/images/newb-table-32-32.png  (128x224, 1-bit grayscale, 4x7 grid of
#   32x32 frames)
#
# Frame layout (1-indexed, lays out left-to-right then top-to-bottom):
#   01 idle_south_a   02 idle_south_b   03 walk_south_1    04 walk_south_2
#   05 walk_south_3   06 walk_south_4   07 idle_north      08 walk_north_1
#   09 walk_north_2   10 walk_north_3   11 walk_north_4    12 (blank)
#   13 idle_east      14 walk_east_1    15 walk_east_2     16 walk_east_3
#   17 walk_east_4    18 (blank)        19 idle_west       20 walk_west_1
#   21 walk_west_2    22 walk_west_3    23 walk_west_4     24 (blank)
#   25 interact       26 surprised      27 (blank)         28 (blank)
#
# Quality bar: must read as a hooded person at 32x32 (Playdate scale rule:
# 32px reads ~16px Game Boy character on device).  Drawn from primitives:
#   - hood arc above the head
#   - oval head
#   - tapered shoulders / body
#   - alternating arm + leg offsets across the 4-frame walk cycle
#   - face/back differentiation per direction
#
# Hand-edit upgrade path: this PNG can be replaced 1:1 with pixel-art frames
# of the same dimensions — the Newb.lua AnimatedSprite wrapper is invariant
# to the source PNG.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="$ROOT/source/images"
TMP_DIR="$(mktemp -d -t newb-sprite-XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$OUT_DIR"

# Common primitive geometry (32x32 cell).
#   x range 0..31, y range 0..31.
#   Pivot: feet ~ y=30, head top ~ y=4.
#   Body silhouette:
#     hood arc:   ellipse cx=16, cy=8, rx=8,  ry=8   (top half)
#     head:       ellipse cx=16, cy=10, rx=5, ry=5
#     shoulders:  trapezoid roughly x=10..22, y=14..16
#     torso:      rect x=11..21, y=15..23
#     legs:       two rects x=11..14 and x=17..20, y=23..30
#     arms:       two rects x=8..10  and x=21..23, y=15..23

cell() {
  # Render one 32x32 cell to $1 using draw commands $2..$N concatenated.
  local out="$1"; shift
  convert -size 32x32 xc:white -fill black -stroke none \
    -draw "$*" \
    "$out"
}

# Blank white cell (placeholder).
blank() {
  convert -size 32x32 xc:white "$1"
}

# --- South-facing draws ---------------------------------------------------
# Direction: south = facing toward camera. Face visible (2 dot eyes).

south_base() {
  # Returns a draw string for the south body excluding arms+legs (those vary
  # per frame).  Includes hood, head, eyes, torso.
  echo "
    fill black ellipse 16,8 9,8 180,360
    fill white ellipse 16,10 5,5 180,360
    fill black ellipse 16,11 5,5 0,180
    fill white circle 14,12 14,13
    fill white circle 18,12 18,13
    fill black polygon 11,14 21,14 22,16 10,16
    fill black rectangle 11,16 21,23
  "
}

south_legs() {
  # $1 = left leg y offset, $2 = right leg y offset
  local ly=$1 ry=$2
  echo "
    fill black rectangle 11,$((23 + ly)) 14,$((30 + ly))
    fill black rectangle 17,$((23 + ry)) 20,$((30 + ry))
  "
}

south_arms() {
  # $1 = left arm y offset, $2 = right arm y offset
  local ly=$1 ry=$2
  echo "
    fill black rectangle 8,$((15 + ly)) 10,$((23 + ly))
    fill black rectangle 21,$((15 + ry)) 23,$((23 + ry))
  "
}

# Frame 01: idle_south_a
cell "$TMP_DIR/01.png" "$(south_base) $(south_legs 0 0) $(south_arms 0 0)"
# Frame 02: idle_south_b (subtle breathing — head 1px down, arms 1px down)
cell "$TMP_DIR/02.png" "
  fill black ellipse 16,9 9,8 180,360
  fill white ellipse 16,11 5,5 180,360
  fill black ellipse 16,12 5,5 0,180
  fill white circle 14,13 14,14
  fill white circle 18,13 18,14
  fill black polygon 11,15 21,15 22,17 10,17
  fill black rectangle 11,17 21,23
  fill black rectangle 11,23 14,30
  fill black rectangle 17,23 20,30
  fill black rectangle 8,16 10,23
  fill black rectangle 21,16 23,23
"
# Walk south — 4 frame cycle: contact, passing, contact-opposite, passing.
# Use leg/arm offsets so the silhouette breaks left/right.
cell "$TMP_DIR/03.png" "$(south_base) $(south_legs -1 1)  $(south_arms 1 -1)"
cell "$TMP_DIR/04.png" "$(south_base) $(south_legs 0 0)   $(south_arms 0 0)"
cell "$TMP_DIR/05.png" "$(south_base) $(south_legs 1 -1)  $(south_arms -1 1)"
cell "$TMP_DIR/06.png" "$(south_base) $(south_legs 0 0)   $(south_arms 0 0)"

# --- North-facing draws ---------------------------------------------------
# Direction: north = facing away. Solid hood back, no face dots, head shape
# slightly fuller because the hood drapes over.

north_base() {
  echo "
    fill black ellipse 16,8 9,9 180,360
    fill black ellipse 16,10 7,6 180,360
    fill black polygon 11,14 21,14 22,16 10,16
    fill black rectangle 11,16 21,23
  "
}

cell "$TMP_DIR/07.png" "$(north_base) $(south_legs 0 0) $(south_arms 0 0)"
cell "$TMP_DIR/08.png" "$(north_base) $(south_legs -1 1) $(south_arms 1 -1)"
cell "$TMP_DIR/09.png" "$(north_base) $(south_legs 0 0)  $(south_arms 0 0)"
cell "$TMP_DIR/10.png" "$(north_base) $(south_legs 1 -1) $(south_arms -1 1)"
cell "$TMP_DIR/11.png" "$(north_base) $(south_legs 0 0)  $(south_arms 0 0)"
blank "$TMP_DIR/12.png"

# --- East-facing draws ----------------------------------------------------
# Profile view. Narrower silhouette, hood tapers forward, single visible eye.

east_base() {
  # Profile body — narrower in x, hood extends forward (right side).
  echo "
    fill black polygon 11,3 21,3 23,8 23,14 9,14 9,8
    fill white ellipse 17,10 3,4 180,360
    fill black ellipse 17,11 3,4 0,180
    fill white circle 18,12 18,13
    fill black polygon 12,14 20,14 21,16 11,16
    fill black rectangle 12,16 20,23
  "
}

east_legs() {
  local fl=$1 bl=$2
  # Front leg slightly to the right, back leg slightly left.
  echo "
    fill black rectangle 13,$((23 + bl)) 16,$((30 + bl))
    fill black rectangle 17,$((23 + fl)) 20,$((30 + fl))
  "
}

east_arm() {
  # Single visible arm on the camera-facing side, swings forward/back.
  local ay=$1 ax=$2
  echo "
    fill black rectangle $((18 + ax)),$((16 + ay)) $((20 + ax)),$((23 + ay))
  "
}

cell "$TMP_DIR/13.png" "$(east_base) $(east_legs 0 0)  $(east_arm 0 0)"
cell "$TMP_DIR/14.png" "$(east_base) $(east_legs -1 1) $(east_arm -1 1)"
cell "$TMP_DIR/15.png" "$(east_base) $(east_legs 0 0)  $(east_arm 0 0)"
cell "$TMP_DIR/16.png" "$(east_base) $(east_legs 1 -1) $(east_arm 1 -1)"
cell "$TMP_DIR/17.png" "$(east_base) $(east_legs 0 0)  $(east_arm 0 0)"
blank "$TMP_DIR/18.png"

# --- West-facing draws ----------------------------------------------------
# Mirror of east. Flip in-place using ImageMagick.

flip_h() {
  convert "$1" -flop "$2"
}

flip_h "$TMP_DIR/13.png" "$TMP_DIR/19.png"
flip_h "$TMP_DIR/14.png" "$TMP_DIR/20.png"
flip_h "$TMP_DIR/15.png" "$TMP_DIR/21.png"
flip_h "$TMP_DIR/16.png" "$TMP_DIR/22.png"
flip_h "$TMP_DIR/17.png" "$TMP_DIR/23.png"
blank "$TMP_DIR/24.png"

# --- Interact + surprised -------------------------------------------------
# Interact: south-facing, right arm extended forward (down).
cell "$TMP_DIR/25.png" "
  $(south_base)
  $(south_legs 0 0)
  fill black rectangle 8,15 10,23
  fill black rectangle 21,18 23,29
  fill black rectangle 20,27 26,29
"

# Surprised: south-facing, head tilted up slightly, both arms raised
# (offset y = -3 so they rise above shoulders), and an exclamation pixel
# above the hood for legibility.
cell "$TMP_DIR/26.png" "
  fill black ellipse 16,7 9,8 180,360
  fill white ellipse 16,9 5,5 180,360
  fill black ellipse 16,10 5,5 0,180
  fill white circle 14,11 14,12
  fill white circle 18,11 18,12
  fill black polygon 11,13 21,13 22,15 10,15
  fill black rectangle 11,15 21,22
  fill black rectangle 11,22 14,29
  fill black rectangle 17,22 20,29
  fill black rectangle 6,11 8,19
  fill black rectangle 23,11 25,19
  fill black rectangle 15,0 17,2
  fill black rectangle 15,3 17,4
"
blank "$TMP_DIR/27.png"
blank "$TMP_DIR/28.png"

# --- Montage --------------------------------------------------------------
# Combine 28 cells into a 4-wide x 7-tall grid (128x224).  -tile 4x7 with no
# borders/padding so cell boundaries align exactly with imagetable
# expectations.

montage \
  "$TMP_DIR"/{01,02,03,04,05,06,07,08,09,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28}.png \
  -tile 4x7 -geometry +0+0 -background white \
  "$TMP_DIR/grid.png"

# 1-bit conversion (Playdate is 1-bit only).
convert "$TMP_DIR/grid.png" -monochrome \
  -define png:bit-depth=1 -define png:color-type=0 \
  "$OUT_DIR/newb-table-32-32.png"

echo "wrote $OUT_DIR/newb-table-32-32.png"
file "$OUT_DIR/newb-table-32-32.png"
