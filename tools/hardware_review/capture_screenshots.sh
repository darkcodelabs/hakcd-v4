#!/usr/bin/env bash
# tools/hardware_review/capture_screenshots.sh
#
# Capture per-scene Simulator screenshots for visual signoff.
# Usage: ./capture_screenshots.sh <pdx_path> <output_dir>
#
# Linux/Simulator caveat: Playdate Simulator on Linux does not expose
# scriptable capture in 3.0.6. This script attempts to drive the
# simulator via xdotool if available; otherwise it prints the manual
# capture protocol for the human running it.

set -euo pipefail

PDX="${1:?usage: capture_screenshots.sh <pdx_path> <output_dir>}"
OUT="${2:?usage: capture_screenshots.sh <pdx_path> <output_dir>}"

mkdir -p "$OUT"

SCENES=(
    TitleScene
    BedroomScene
    ComputerScene
    ModemScene
    PhoneScene
    PlaygroundScene
    LockpickScene
    TysonScene
    CoinVaultScene
)

print_manual_protocol() {
    cat <<MANUAL
Manual capture protocol:
  1. Open Playdate Simulator
  2. File > Open > ${PDX}
  3. For each scene below, navigate, then File > Save Screen
     (or use the system screenshot tool on the Simulator window)
  4. Save as <scene>.png in: ${OUT}
  5. Scenes to capture (9 minimum):
MANUAL
    for scene in "${SCENES[@]}"; do
        echo "     - ${scene}"
    done
    cat <<NAMING

Naming convention:
  Simulator screenshots: <scene>.png  (e.g. TitleScene.png)
  Device photos (separate step): <scene>_arm.jpg in ../device/

After capture, copy per_version_template.md to ../SIGNOFF.md
and fill in the per-asset verdict table.
NAMING
}

if ! command -v xdotool >/dev/null 2>&1; then
    print_manual_protocol
    exit 0
fi

# (xdotool path — best-effort, requires user to position Simulator window)
echo "xdotool detected — attempting automated capture (best-effort)..."
echo "Open the Simulator window manually; press Enter when ready."
read -r
# (in practice this would drive the sim; left as scaffolding)
echo "Automated capture not yet implemented for Linux Simulator."
echo "Use manual capture protocol above:"
echo
print_manual_protocol
exit 1
