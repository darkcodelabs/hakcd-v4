#!/usr/bin/env bash
# build_tileset.sh — generate hakcd-table-24-24.png
#
# HAKCD v4 tileset builder. Produces a 192x192 1-bit PNG containing 64 tiles
# arranged in an 8x8 grid of 24x24 cells. Tiles are composed in ImageMagick
# from 1-bit dither patterns inspired by GFXP — no AI-generated art, no
# wireframe boxes, no placeholders. Re-run after edits to regenerate.
#
# Output: source/images/tilesets/hakcd-table-24-24.png
#
# Tile index layout (row, col -> id):
#   row 0: empty | wood floor | carpet | concrete | brick floor | window | rotary phone | floppy
#   row 1: brick-lt | brick-dk | plaster | metal panel | corner-TL | corner-TR | edge-top | wall-ctr
#   row 2: corner-BL | corner-BR | edge-bot | edge-L | edge-R | door-closed | door-open | modem
#   row 3: bed-top | bed-bot | computer-CRT | computer-tower | workbench-L | workbench-R | payphone | CRT TV
#   row 4: server-rack | arcade-top | arcade-bot | coin-vault | portal-glow | window-cracked | desk-L | desk-R
#   rows 5-7: reserved blanks (transparent)

set -euo pipefail

cd "$(dirname "$0")/../.."
OUT="source/images/tilesets/hakcd-table-24-24.png"
TMP="$(mktemp -d)"
trap "rm -rf $TMP" EXIT

T=24       # tile size in px
GW=8       # grid width in tiles
GH=8       # grid height in tiles
SHEET_W=$((T*GW))
SHEET_H=$((T*GH))

# -----------------------------------------------------------------------------
# tile helpers — each writes a 24x24 PNG to $TMP/tNN.png
# -----------------------------------------------------------------------------

blank() { # $1 outfile
  convert -size "${T}x${T}" xc:white "$1"
}

wood_floor() {
  # diagonal plank with 1-bit hatch
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "line 0,7 23,7" \
    -draw "line 0,15 23,15" \
    -draw "line 0,23 23,23" \
    -fill black -draw "point 3,2 point 11,2 point 19,2" \
    -draw "point 7,10 point 15,10 point 23,10" \
    -draw "point 3,18 point 11,18 point 19,18" \
    "$1"
}

carpet() {
  # dense checker dither — 50% gray feel
  convert -size "${T}x${T}" pattern:gray50 -monochrome "$1"
}

concrete() {
  # sparse stipple — pattern:gray12
  convert -size "${T}x${T}" pattern:gray25 -monochrome "$1"
}

brick_floor() {
  # offset bricks horizontal
  convert -size "${T}x${T}" xc:white \
    -fill black \
    -draw "line 0,7 23,7" \
    -draw "line 0,15 23,15" \
    -draw "line 0,23 23,23" \
    -draw "line 11,0 11,7" \
    -draw "line 5,8 5,15" -draw "line 17,8 17,15" \
    -draw "line 11,16 11,23" \
    "$1"
}

window() {
  # window frame with 4 panes + cracked-blind dither
  convert -size "${T}x${T}" xc:white \
    -fill none -stroke black -strokewidth 1 \
    -draw "rectangle 0,0 23,23" \
    -draw "line 11,0 11,23" \
    -draw "line 0,11 23,11" \
    -fill black -draw "point 3,3 point 7,5 point 5,7 point 15,3 point 19,5 point 17,7" \
    -draw "point 3,15 point 7,17 point 5,19 point 15,15 point 19,17 point 17,19" \
    "$1"
}

rotary_phone() {
  # squat receiver + dial body
  convert -size "${T}x${T}" xc:white \
    -fill black \
    -draw "roundRectangle 2,8 21,21 3,3" \
    -fill white \
    -draw "circle 11,15 11,10" \
    -fill black \
    -draw "circle 11,15 11,12" \
    -fill white -draw "point 11,11 point 14,12 point 16,15 point 14,18 point 11,19 point 8,18 point 6,15 point 8,12" \
    -fill black -draw "roundRectangle 1,3 22,6 2,2" \
    -fill white -draw "rectangle 4,4 6,5" -draw "rectangle 17,4 19,5" \
    "$1"
}

floppy() {
  # 3.5" floppy disk silhouette
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 2,2 21,21" \
    -fill white -draw "rectangle 6,3 17,9" \
    -fill black -draw "rectangle 8,4 10,7" \
    -fill white -draw "rectangle 4,12 19,20" \
    -fill black -draw "rectangle 7,14 16,16" -draw "rectangle 7,17 16,18" \
    "$1"
}

brick_wall_lt() {
  # light brick — outline with sparse dither
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "line 0,0 23,0 line 0,7 23,7 line 0,15 23,15 line 0,23 23,23" \
    -draw "line 0,0 0,23 line 11,0 11,7 line 5,8 5,15 line 17,8 17,15 line 11,16 11,23 line 23,0 23,23" \
    -draw "point 3,3 point 15,3 point 9,11 point 21,11 point 3,19 point 15,19" \
    "$1"
}

brick_wall_dk() {
  # dark brick — solid bricks with mortar lines
  convert -size "${T}x${T}" xc:black \
    -fill white -draw "line 0,7 23,7 line 0,15 23,15 line 0,23 23,23 line 11,0 11,7 line 5,8 5,15 line 17,8 17,15 line 11,16 11,23" \
    "$1"
}

plaster_wall() {
  # smooth wall with sparse hand-placed stipple — gray12 pattern is unavailable
  # in IM6, so we paint a sparse 3x3 dot grid manually for the same look.
  convert -size "${T}x${T}" xc:white \
    -fill black \
    -draw "point 2,2 point 11,2 point 20,2" \
    -draw "point 6,7 point 15,7 point 23,7" \
    -draw "point 2,11 point 11,11 point 20,11" \
    -draw "point 6,16 point 15,16 point 23,16" \
    -draw "point 2,20 point 11,20 point 20,20" \
    "$1"
}

metal_panel() {
  # rivets in corners + edges
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 0,0 23,23" \
    -fill white -draw "rectangle 2,2 21,21" \
    -fill black -draw "point 4,4 point 19,4 point 4,19 point 19,19 point 11,4 point 11,19 point 4,11 point 19,11" \
    -draw "line 2,11 21,11" -draw "line 11,2 11,21" \
    "$1"
}

wall_corner_tl() {
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 0,0 23,5" -draw "rectangle 0,0 5,23" "$1"
}
wall_corner_tr() {
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 0,0 23,5" -draw "rectangle 18,0 23,23" "$1"
}
wall_corner_bl() {
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 0,18 23,23" -draw "rectangle 0,0 5,23" "$1"
}
wall_corner_br() {
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 0,18 23,23" -draw "rectangle 18,0 23,23" "$1"
}
wall_edge_top() {
  convert -size "${T}x${T}" xc:white -fill black -draw "rectangle 0,0 23,5" "$1"
}
wall_edge_bot() {
  convert -size "${T}x${T}" xc:white -fill black -draw "rectangle 0,18 23,23" "$1"
}
wall_edge_l() {
  convert -size "${T}x${T}" xc:white -fill black -draw "rectangle 0,0 5,23" "$1"
}
wall_edge_r() {
  convert -size "${T}x${T}" xc:white -fill black -draw "rectangle 18,0 23,23" "$1"
}
wall_center() {
  # solid black filler — used for collision blocks
  convert -size "${T}x${T}" xc:black "$1"
}

door_closed() {
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 2,1 21,23" \
    -fill white -draw "rectangle 4,3 19,21" \
    -draw "line 4,12 19,12" \
    -fill black -draw "circle 17,12 17,14" \
    "$1"
}
door_open() {
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 2,1 5,23" -draw "rectangle 18,1 21,23" \
    -draw "rectangle 2,1 21,3" \
    "$1"
}

modem() {
  # rectangular box with two indicator LEDs and a phone jack
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 1,6 22,20" \
    -fill white -draw "rectangle 3,8 20,18" \
    -fill black -draw "circle 6,12 6,14" -draw "circle 12,12 12,14" -draw "circle 18,12 18,14" \
    -draw "rectangle 7,16 16,17" \
    -draw "rectangle 9,20 14,23" \
    "$1"
}

bed_top() {
  # pillow + bedsheet top
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 0,8 23,23" \
    -fill white -draw "rectangle 2,10 21,21" \
    -fill black -draw "roundRectangle 4,12 19,17 2,2" \
    "$1"
}
bed_bot() {
  # bedsheet bottom + footboard
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 0,0 23,15" \
    -fill white -draw "rectangle 2,0 21,13" \
    -draw "point 4,4 point 10,2 point 16,5 point 6,8 point 14,9 point 18,3" \
    -fill black -draw "rectangle 0,16 23,23" \
    "$1"
}

computer_crt() {
  # CRT monitor on top of tower
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 1,1 22,18" \
    -fill white -draw "rectangle 3,3 20,16" \
    -fill black -draw "point 5,5 point 7,7 point 9,5 point 11,9 point 15,5 point 17,11 point 6,12 point 14,13" \
    -draw "rectangle 8,19 15,20" \
    -draw "rectangle 4,21 19,23" \
    "$1"
}
computer_tower() {
  # PC tower (vertical)
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 4,0 19,23" \
    -fill white -draw "rectangle 6,2 17,5" \
    -draw "rectangle 6,7 17,9" \
    -draw "circle 12,16 12,19" \
    -fill black -draw "point 12,16" \
    "$1"
}

workbench_l() {
  # left half of bench: legs + tool slot
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 0,4 23,9" \
    -fill white -draw "rectangle 2,6 21,8" \
    -fill black -draw "rectangle 2,10 5,23" \
    -fill black -draw "rectangle 6,11 21,15" \
    -fill white -draw "rectangle 8,12 11,14" -draw "rectangle 13,12 17,14" \
    "$1"
}
workbench_r() {
  # right half of bench: vice + scattered screws
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 0,4 23,9" \
    -fill white -draw "rectangle 2,6 21,8" \
    -fill black -draw "rectangle 18,10 21,23" \
    -fill black -draw "rectangle 2,11 17,15" \
    -fill white -draw "rectangle 4,12 7,14" \
    -fill black -draw "point 9,17 point 13,18 point 6,20 point 11,22" \
    "$1"
}

payphone() {
  # vertical payphone box with handset
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 5,0 18,23" \
    -fill white -draw "rectangle 7,2 16,9" \
    -draw "rectangle 7,11 16,14" \
    -draw "rectangle 9,16 14,21" \
    -fill black -draw "rectangle 0,7 5,12" -draw "rectangle 1,8 4,11" \
    "$1"
}

crt_tv() {
  # boxy TV with antennas and rounded screen
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "line 6,0 9,5" -draw "line 17,0 14,5" \
    -draw "rectangle 1,5 22,21" \
    -fill white -draw "roundRectangle 3,7 20,19 2,2" \
    -fill black -draw "point 7,11 point 13,9 point 16,13 point 10,15 point 18,17" \
    -fill black -draw "circle 19,20 19,22" \
    -draw "rectangle 3,22 20,23" \
    "$1"
}

server_rack() {
  # 1U units stacked with blinking LEDs
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 1,0 22,23" \
    -fill white -draw "rectangle 3,2 20,5" \
    -draw "rectangle 3,7 20,10" \
    -draw "rectangle 3,12 20,15" \
    -draw "rectangle 3,17 20,20" \
    -fill black -draw "point 5,3 point 7,3 point 5,8 point 7,8 point 5,13 point 7,13 point 5,18 point 7,18" \
    "$1"
}

arcade_top() {
  # marquee + screen
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 2,0 21,5" \
    -fill white -draw "rectangle 4,1 19,4" \
    -fill black -draw "rectangle 2,7 21,21" \
    -fill white -draw "rectangle 4,9 19,19" \
    -fill black -draw "point 7,12 point 11,11 point 15,13 point 9,15 point 13,16 point 16,17" \
    -draw "rectangle 6,21 17,23" \
    "$1"
}
arcade_bot() {
  # joystick + buttons + base
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 2,0 21,7" \
    -fill white -draw "circle 7,3 7,5" \
    -fill black -draw "point 7,3" \
    -fill white -draw "circle 13,3 13,4" -draw "circle 17,3 17,4" \
    -fill black -draw "rectangle 2,9 21,23" \
    -fill white -draw "rectangle 4,12 19,20" \
    -draw "point 8,14 point 14,15 point 11,17 point 7,19 point 16,18" \
    "$1"
}

coin_vault() {
  # pedestal with coin glow
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 3,17 20,23" \
    -draw "rectangle 5,13 18,17" \
    -fill white -draw "circle 11,9 11,3" \
    -fill black -draw "circle 11,9 11,4" \
    -fill white -draw "point 11,7 point 13,9 point 11,11 point 9,9 point 11,8 point 12,10 point 10,10 point 10,8 point 12,8" \
    "$1"
}

portal_pedestal() {
  # pedestal with halo ring around top
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 5,17 18,23" \
    -fill white -draw "rectangle 7,18 16,22" \
    -fill black -draw "circle 11,11 11,4" \
    -fill white -draw "circle 11,11 11,7" \
    -fill black -draw "circle 11,11 11,9" \
    -fill white -draw "point 11,11" \
    -draw "point 11,2 point 18,5 point 20,11 point 18,17 point 11,20 point 4,17 point 2,11 point 4,5" \
    "$1"
}

window_cracked() {
  # cracked blinds — diagonal cracks across pane
  convert -size "${T}x${T}" xc:white \
    -fill none -stroke black -strokewidth 1 \
    -draw "rectangle 0,0 23,23" \
    -draw "line 0,4 23,4" -draw "line 0,9 23,9" -draw "line 0,14 23,14" -draw "line 0,19 23,19" \
    -draw "line 3,1 8,22" -draw "line 11,2 18,21" \
    "$1"
}

desk_l() {
  # desk left edge with leg
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 0,2 23,8" \
    -fill white -draw "rectangle 2,4 21,7" \
    -draw "point 4,5 point 8,6 point 14,5 point 18,6" \
    -fill black -draw "rectangle 2,9 5,23" \
    "$1"
}
desk_r() {
  # desk right edge with leg + drawer
  convert -size "${T}x${T}" xc:white \
    -fill black -draw "rectangle 0,2 23,8" \
    -fill white -draw "rectangle 2,4 21,7" \
    -fill black -draw "rectangle 18,9 21,23" \
    -draw "rectangle 4,10 16,19" \
    -fill white -draw "rectangle 6,12 14,17" \
    -draw "point 10,14" \
    "$1"
}

# -----------------------------------------------------------------------------
# generate all tiles by index
# -----------------------------------------------------------------------------
mkdir -p "$TMP/cells"

# row 0
blank          "$TMP/cells/00.png"
wood_floor     "$TMP/cells/01.png"
carpet         "$TMP/cells/02.png"
concrete       "$TMP/cells/03.png"
brick_floor    "$TMP/cells/04.png"
window         "$TMP/cells/05.png"
rotary_phone   "$TMP/cells/06.png"
floppy         "$TMP/cells/07.png"

# row 1
brick_wall_lt  "$TMP/cells/08.png"
brick_wall_dk  "$TMP/cells/09.png"
plaster_wall   "$TMP/cells/10.png"
metal_panel    "$TMP/cells/11.png"
wall_corner_tl "$TMP/cells/12.png"
wall_corner_tr "$TMP/cells/13.png"
wall_edge_top  "$TMP/cells/14.png"
wall_center    "$TMP/cells/15.png"

# row 2
wall_corner_bl "$TMP/cells/16.png"
wall_corner_br "$TMP/cells/17.png"
wall_edge_bot  "$TMP/cells/18.png"
wall_edge_l    "$TMP/cells/19.png"
wall_edge_r    "$TMP/cells/20.png"
door_closed    "$TMP/cells/21.png"
door_open      "$TMP/cells/22.png"
modem          "$TMP/cells/23.png"

# row 3
bed_top        "$TMP/cells/24.png"
bed_bot        "$TMP/cells/25.png"
computer_crt   "$TMP/cells/26.png"
computer_tower "$TMP/cells/27.png"
workbench_l    "$TMP/cells/28.png"
workbench_r    "$TMP/cells/29.png"
payphone       "$TMP/cells/30.png"
crt_tv         "$TMP/cells/31.png"

# row 4
server_rack     "$TMP/cells/32.png"
arcade_top      "$TMP/cells/33.png"
arcade_bot      "$TMP/cells/34.png"
coin_vault      "$TMP/cells/35.png"
portal_pedestal "$TMP/cells/36.png"
window_cracked  "$TMP/cells/37.png"
desk_l          "$TMP/cells/38.png"
desk_r          "$TMP/cells/39.png"

# rows 5-7 reserved blanks (40..63)
for i in $(seq 40 63); do
  printf -v n "%02d" "$i"
  blank "$TMP/cells/${n}.png"
done

# -----------------------------------------------------------------------------
# montage into 8x8 sheet, force 1-bit
# -----------------------------------------------------------------------------
mkdir -p "$(dirname "$OUT")"
montage "$TMP/cells/"??.png \
  -tile "${GW}x${GH}" -geometry "${T}x${T}+0+0" -background white \
  png:- | \
convert - -depth 1 -monochrome -define png:bit-depth=1 -define png:color-type=0 "$OUT"

# verify dimensions
got_dim=$(identify -format "%wx%h" "$OUT")
expected="${SHEET_W}x${SHEET_H}"
if [ "$got_dim" != "$expected" ]; then
  echo "ERROR: tileset is $got_dim, expected $expected" >&2
  exit 1
fi

echo "wrote $OUT ($got_dim, 1-bit)"
