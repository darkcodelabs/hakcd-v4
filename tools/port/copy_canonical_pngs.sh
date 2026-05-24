#!/usr/bin/env bash
# tools/port/copy_canonical_pngs.sh
#
# Convert canonical art (from 23studios/docs/) into 1-bit dithered PNGs at
# the dimensions the Playdate scenes expect. Run from project root.
#
#   bash tools/port/copy_canonical_pngs.sh
#
# Outputs:
#   source/images/title.png                400x240
#   source/images/pwnglove_icon.png        200x200
#   source/images/coins/coin_0..3.png      48x48  (grid)
#   source/images/coins/coin_0..3_large.png 200x200 (closeup)
#   source/images/coins/coin_locked.png    48x48  "?" placeholder
#   source/images/ui/lockpick_body.png     240x100 lock cutaway
#
# Idempotent — safe to re-run. Source assets are read-only.

set -euo pipefail

DOCS="/home/hakcer/projects/23studios/docs"
OUT="source/images"
PNG_OPTS=(-define png:bit-depth=1 -define png:color-type=0)
DITHER=(-ordered-dither o4x4 -monochrome)

mkdir -p "${OUT}/coins" "${OUT}/ui" "${OUT}/portraits"

echo "[port] title.png (400x240)"
convert "${DOCS}/hakcd_title.png" \
    -resize 400x240^ -gravity center -extent 400x240 \
    "${DITHER[@]}" "${PNG_OPTS[@]}" \
    "${OUT}/title.png"

echo "[port] pwnglove_icon.png (200x200)"
convert "${DOCS}/gamepwnglovev2.png" \
    -resize 200x200 \
    "${DITHER[@]}" "${PNG_OPTS[@]}" \
    "${OUT}/pwnglove_icon.png"

# Coins — 4 known canonical art files from the v0.0.3 source.
# coin0.png and coingame.png crops live in docs/. coin1.jpg / coin2.jpg are
# camera photos so they get the same dither pass. coin3 is not in docs/ yet,
# so we reuse the v0.0.3 source PNG if present, else fall back to coin0.
COIN_SRC_0="${DOCS}/coin0.png"
COIN_SRC_1="${DOCS}/coin1.jpg"
COIN_SRC_2="${DOCS}/coin2.jpg"
# coin3 fallback chain — bible_media first, then v0.0.3 processed PNG.
COIN_SRC_3=""
for cand in \
    "/home/hakcer/projects/personal/hakcd/bible_media/art/23coins_coin3_real.png" \
    "/home/hakcer/projects/personal/hakcd/source/images/coins/coin_3_large.png" \
    "${DOCS}/coin0.png" ; do
    if [[ -f "$cand" ]]; then COIN_SRC_3="$cand"; break; fi
done

declare -a COIN_SRCS=("$COIN_SRC_0" "$COIN_SRC_1" "$COIN_SRC_2" "$COIN_SRC_3")

for i in 0 1 2 3 ; do
    SRC="${COIN_SRCS[$i]}"
    echo "[port] coin_${i}.png  + coin_${i}_large.png  (src: ${SRC})"
    convert "${SRC}" \
        -resize 48x48^ -gravity center -extent 48x48 \
        "${DITHER[@]}" "${PNG_OPTS[@]}" \
        "${OUT}/coins/coin_${i}.png"
    convert "${SRC}" \
        -resize 200x200^ -gravity center -extent 200x200 \
        "${DITHER[@]}" "${PNG_OPTS[@]}" \
        "${OUT}/coins/coin_${i}_large.png"
done

echo "[port] coin_locked.png (48x48 placeholder)"
convert -size 48x48 xc:white \
    -fill black -stroke black -draw "rectangle 1,1 46,46" \
    -fill white -draw "rectangle 3,3 44,44" \
    -gravity center -pointsize 26 -fill black -annotate +0+0 "?" \
    "${DITHER[@]}" "${PNG_OPTS[@]}" \
    "${OUT}/coins/coin_locked.png"

# Lockpick body — generate a 240x100 lock cutaway with 5 pin tumblers.
# v0.0.3 has a hand-drawn PNG at /home/hakcer/projects/personal/hakcd/source/images/ui/lockpick_body.png
# if available, copy that through the dither pass so the v4 version matches.
LP_SRC="/home/hakcer/projects/personal/hakcd/source/images/ui/lockpick_body.png"
if [[ -f "$LP_SRC" ]]; then
    echo "[port] lockpick_body.png  (from v0.0.3 source)"
    convert "$LP_SRC" \
        -resize 240x100\! \
        "${DITHER[@]}" "${PNG_OPTS[@]}" \
        "${OUT}/ui/lockpick_body.png"
else
    echo "[port] lockpick_body.png  (generated cutaway)"
    convert -size 240x100 xc:white \
        -fill white -stroke black -strokewidth 2 \
        -draw "roundrectangle 4,4 236,96 8,8" \
        -strokewidth 1 \
        -draw "line 16,52 224,52" \
        -draw "rectangle 30,16 50,86" \
        -draw "rectangle 70,16 90,86" \
        -draw "rectangle 110,16 130,86" \
        -draw "rectangle 150,16 170,86" \
        -draw "rectangle 190,16 210,86" \
        "${DITHER[@]}" "${PNG_OPTS[@]}" \
        "${OUT}/ui/lockpick_body.png"
fi

# newb portrait — required by lockpick + coin vault dialog bar.
# Copy from v0.0.3 source if present; otherwise leave absent and let scenes
# fall back to a text label.
NEWB_SRC="/home/hakcer/projects/personal/hakcd/source/images/portraits/newb.png"
if [[ -f "$NEWB_SRC" ]]; then
    echo "[port] portraits/newb.png  (from v0.0.3 source)"
    convert "$NEWB_SRC" \
        -resize 48x56\! \
        "${DITHER[@]}" "${PNG_OPTS[@]}" \
        "${OUT}/portraits/newb.png"
fi

echo "[port] done."
