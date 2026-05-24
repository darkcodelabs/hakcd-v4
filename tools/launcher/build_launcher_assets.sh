#!/usr/bin/env bash
# tools/launcher/build_launcher_assets.sh
# Derives Playdate launcher assets from the canonical HAKCD title PNG.
# Replaces source/assets/launcher/{card,card-pressed,launchImage}.png +
# source/icon.png so the home-screen tile + boot splash + icon all match
# the in-game title — NOT the Noble Engine template default.
#
# Sizes per https://sdk.play.date/3.0.6/Inside%20Playdate.html#f-launcherImages:
#   card.png         350x155 (game card on system home)
#   card-pressed.png 350x155 (pressed state of card)
#   launchImage.png  400x240 (full-screen during boot)
#   icon.png         32x32   (small icon used in some launcher modes)

set -euo pipefail

SRC="${1:-/home/hakcer/projects/23studios/docs/hakcd_title.png}"
LAUNCHER_DIR="${2:-/home/hakcer/projects/hakcd-v4/source/assets/launcher}"
ICON_DIR="${3:-/home/hakcer/projects/hakcd-v4/source}"

mkdir -p "$LAUNCHER_DIR"

# Card (static)
convert "$SRC" -resize 350x155^ -gravity center -extent 350x155 \
  -ordered-dither o4x4 -monochrome -define png:bit-depth=1 -define png:color-type=0 \
  "$LAUNCHER_DIR/card.png"

# Card pressed = same image for now (animations live in card-highlighted/, removed)
cp "$LAUNCHER_DIR/card.png" "$LAUNCHER_DIR/card-pressed.png"

# Remove Noble template's multi-frame card-highlighted + launchImages dirs
rm -rf "$LAUNCHER_DIR/card-highlighted"
rm -rf "$LAUNCHER_DIR/launchImages"

# Single static launch image
convert "$SRC" -resize 400x240^ -gravity center -extent 400x240 \
  -ordered-dither o4x4 -monochrome -define png:bit-depth=1 -define png:color-type=0 \
  "$LAUNCHER_DIR/launchImage.png"

# Icon (32x32)
convert "$SRC" -resize 32x32^ -gravity center -extent 32x32 \
  -ordered-dither o4x4 -monochrome -define png:bit-depth=1 -define png:color-type=0 \
  "$ICON_DIR/icon.png"

echo "Launcher assets rebuilt from canonical:"
file "$LAUNCHER_DIR/card.png" \
     "$LAUNCHER_DIR/card-pressed.png" \
     "$LAUNCHER_DIR/launchImage.png" \
     "$ICON_DIR/icon.png"
