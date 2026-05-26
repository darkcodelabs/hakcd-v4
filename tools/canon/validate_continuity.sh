#!/usr/bin/env bash
# tools/canon/validate_continuity.sh
# Phase 7 of canon-first migration plan.
#
# Reads source/data/{canon,continuity,assets,animations,rooms}.lua and
# cross-checks the graph for the 9 drift patterns enumerated below.
# Fails non-zero on any violation, printing path + id of the offender.
#
# Independent of pdc / Lua interpreter — heuristic line-scan over the
# generated manifests (they have predictable one-key-per-line shape).
# Run as a pre-compile gate via the Makefile validate-canon target.
#
# Checks:
#   1. Missing scene reference         continuity.transitions_to -> source/scenes/<Name>.lua
#   2. Missing room reference          continuity.scenes[].room  -> canon.rooms[]  AND rooms.lua
#   3. Missing object reference        continuity.scenes[].objects[] -> canon.objects[]
#   4. Missing asset on disk           assets.lua[].path actually exists under source/
#   5. Missing animation frame         animations.<char>.<state>.frames[] index <= asset.frame_count
#   6. Missing dialogue speaker        canon.dialogue_ids[].speaker -> canon.characters OR system/newb literal
#   7. Undeclared state flag           continuity required/sets flags -> canon.state_flags
#   8. Invalid transition target       continuity.transitions_to[] -> canon.scenes[]
#   9. Hotspot launches sanity         canon.objects[].launches -> canon.scenes[]
#
# Usage:
#   ./tools/canon/validate_continuity.sh
#   exits 0 on full pass, 1 on any violation.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

CANON="source/data/canon.lua"
CONTINUITY="source/data/continuity.lua"
ASSETS="source/data/assets.lua"
ANIMATIONS="source/data/animations.lua"
ROOMS="source/data/rooms.lua"
SCENES_DIR="source/scenes"

for f in "$CANON" "$CONTINUITY" "$ASSETS" "$ANIMATIONS" "$ROOMS"; do
  if [ ! -f "$f" ]; then
    echo "FAIL validate_continuity: required data file missing: $f"
    exit 2
  fi
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail=0
failed_checks=""

note_fail() {
  fail=1
  failed_checks="${failed_checks} $1"
}

# ---- Extract canonical id sets ------------------------------------------------
# canon.scenes ids (top-level keys inside `canon.scenes = { ... }`)
sed -n '/^canon\.scenes = {/,/^}/p' "$CANON" \
  | grep -E '^\s{4}[A-Z][A-Za-z0-9_]+ = \{' \
  | sed -E 's/^\s+([A-Za-z0-9_]+) = \{.*/\1/' \
  | sort -u > "$TMP/canon_scenes"

# canon.rooms ids
sed -n '/^canon\.rooms = {/,/^}/p' "$CANON" \
  | grep -E '^\s{4}[a-z0-9_]+ = \{' \
  | sed -E 's/^\s+([a-z0-9_]+) = \{.*/\1/' \
  | sort -u > "$TMP/canon_rooms"

# canon.objects ids
sed -n '/^canon\.objects = {/,/^}/p' "$CANON" \
  | grep -E '^\s{4}[a-z0-9_]+ = \{' \
  | sed -E 's/^\s+([a-z0-9_]+) = \{.*/\1/' \
  | sort -u > "$TMP/canon_objects"

# canon.characters ids
sed -n '/^canon\.characters = {/,/^canon\.rooms = /p' "$CANON" \
  | grep -E '^\s{4}[a-z0-9_]+ = \{' \
  | sed -E 's/^\s+([a-z0-9_]+) = \{.*/\1/' \
  | sort -u > "$TMP/canon_characters"

# canon.state_flags ids
sed -n '/^canon\.state_flags = {/,/^}/p' "$CANON" \
  | grep -E '^\s{4}[a-z0-9_]+ = \{' \
  | sed -E 's/^\s+([a-z0-9_]+) = \{.*/\1/' \
  | sort -u > "$TMP/canon_state_flags"

# canon.dialogue_ids entries — capture id + speaker pairs (one per top-level entry)
sed -n '/^canon\.dialogue_ids = {/,/^}/p' "$CANON" \
  | awk '
      /^    [a-z0-9_]+ = \{/ {
        match($0, /^    ([a-z0-9_]+)/, m); cur = m[1]; next
      }
      /speaker = "/ && cur != "" {
        match($0, /speaker = "([^"]+)"/, m); print cur " " m[1]; cur = ""
      }
    ' > "$TMP/dialogue_pairs"

# rooms.lua ids (top-level keys)
sed -n '/^local rooms = {/,/^}/p' "$ROOMS" \
  | grep -E '^\s{4}[a-z0-9_]+ = \{' \
  | sed -E 's/^\s+([a-z0-9_]+) = \{.*/\1/' \
  | sort -u > "$TMP/rooms_lua_ids"

# scenes on disk
ls "$SCENES_DIR" 2>/dev/null | grep -E '\.lua$' | sed 's/\.lua$//' | sort -u > "$TMP/scene_files"

# canon.objects.launches values
grep -E 'launches = "' "$CANON" \
  | sed -E 's/.*launches = "([^"]+)".*/\1/' \
  | sort -u > "$TMP/object_launches"

# ---- Parse continuity.scenes into per-scene blocks ---------------------------
# Each top-level entry begins `    {` and ends `    },` — split into per-entry
# files so per-scene lists (room/objects/transitions_to/required_flags/sets_flags)
# can be scoped to one scene without cross-contamination.
awk '
  /^continuity\.scenes = {/ { in_scenes = 1; next }
  in_scenes && /^}/ { in_scenes = 0 }
  in_scenes && /^    \{/ { idx++; out_file = sprintf("'"$TMP"'/scene_%03d", idx); next }
  in_scenes && /^    \},?$/ { out_file = "" ; next }
  in_scenes && out_file != "" { print >> out_file }
' "$CONTINUITY"

# Resolve each scene file -> id
for sf in "$TMP"/scene_*; do
  [ -f "$sf" ] || continue
  sid=$(grep -E '^\s+id = "' "$sf" | head -1 | sed -E 's/.*id = "([^"]+)".*/\1/')
  echo "$sid" >> "$TMP/continuity_scene_ids"
  echo "$sf $sid" >> "$TMP/continuity_scene_index"
done
sort -u "$TMP/continuity_scene_ids" > "$TMP/continuity_scene_ids.sorted" 2>/dev/null || true

# Helper: pull a per-scene block list (objects/transitions_to/required_flags/sets_flags/characters)
list_block() {
  local file="$1" key="$2"
  awk -v key="$key" '
    $0 ~ "^    " key " = \\{" { in_block = 1; if ($0 ~ /\}/) in_block = 0; next }
    in_block && /^    \}/ { in_block = 0; next }
    in_block { print }
  ' "$file" \
    | grep -E '^\s+"' \
    | sed -E 's/.*"([^"]+)".*/\1/'
}

# ============================================================================
# CHECK 1 — every transitions_to[] resolves to source/scenes/<Name>.lua
# ============================================================================
violations=""
for sf in "$TMP"/scene_*; do
  [ -f "$sf" ] || continue
  sid=$(grep -E '^\s+id = "' "$sf" | head -1 | sed -E 's/.*id = "([^"]+)".*/\1/')
  for target in $(list_block "$sf" "transitions_to"); do
    if ! grep -qx "$target" "$TMP/scene_files"; then
      violations="${violations}\n  [check1 missing-scene-file] continuity scene '$sid' transitions_to '$target' — no source/scenes/${target}.lua"
    fi
  done
done
if [ -n "$violations" ]; then echo -e "FAIL check1 (missing scene file):${violations}"; note_fail "check1"; fi

# ============================================================================
# CHECK 2 — continuity.scenes[].room resolves in canon.rooms AND rooms.lua
# ============================================================================
violations=""
for sf in "$TMP"/scene_*; do
  [ -f "$sf" ] || continue
  sid=$(grep -E '^\s+id = "' "$sf" | head -1 | sed -E 's/.*id = "([^"]+)".*/\1/')
  room=$(grep -E '^\s+room = "' "$sf" | head -1 | sed -E 's/.*room = "([^"]+)".*/\1/')
  [ -z "$room" ] && continue
  if ! grep -qx "$room" "$TMP/canon_rooms"; then
    violations="${violations}\n  [check2 missing-canon-room] continuity scene '$sid' room '$room' not in canon.rooms"
  fi
  if ! grep -qx "$room" "$TMP/rooms_lua_ids"; then
    violations="${violations}\n  [check2 missing-rooms-lua] continuity scene '$sid' room '$room' not in rooms.lua"
  fi
done
if [ -n "$violations" ]; then echo -e "FAIL check2 (missing room reference):${violations}"; note_fail "check2"; fi

# ============================================================================
# CHECK 3 — continuity.scenes[].objects[] resolves in canon.objects
# ============================================================================
violations=""
for sf in "$TMP"/scene_*; do
  [ -f "$sf" ] || continue
  sid=$(grep -E '^\s+id = "' "$sf" | head -1 | sed -E 's/.*id = "([^"]+)".*/\1/')
  for obj in $(list_block "$sf" "objects"); do
    if ! grep -qx "$obj" "$TMP/canon_objects"; then
      violations="${violations}\n  [check3 missing-canon-object] continuity scene '$sid' object '$obj' not in canon.objects"
    fi
  done
done
if [ -n "$violations" ]; then echo -e "FAIL check3 (missing object reference):${violations}"; note_fail "check3"; fi

# ============================================================================
# CHECK 4 — every assets.lua entry's path resolves as a file under source/
# Lua loaders omit the extension; tolerate {.png .gif .pdi .pdt .wav .mp3 .pda}.
# ============================================================================
violations=""
while IFS= read -r p; do
  abs="source/$p"
  found=0
  for ext in .png .gif .pdi .pdt .wav .mp3 .pda ""; do
    if [ -f "${abs}${ext}" ]; then found=1; break; fi
  done
  if [ "$found" -eq 0 ]; then
    violations="${violations}\n  [check4 missing-asset-on-disk] path '$p' has no file at source/${p}.{png,gif,pdi,pdt,wav,mp3,pda}"
  fi
done < <(grep -E '^\s+path = "' "$ASSETS" | sed -E 's|^\s+path = "([^"]+)".*|\1|' | sort -u)
if [ -n "$violations" ]; then echo -e "FAIL check4 (missing asset on disk):${violations}"; note_fail "check4"; fi

# ============================================================================
# CHECK 5 — animation frame indices <= corresponding asset frame_count
# Build path -> frame_count map from assets.lua, then for each
# animations.<char>.<state>, look up the character's sprite_table path via
# canon.animation_names.<id>.sprite_table, find that asset, compare frames.
# ============================================================================
# Build asset path -> frame_count map
awk '
  /^\s+\{/ { cur_path = ""; cur_fc = "" }
  /path = "/ { match($0, /path = "([^"]+)"/, m); cur_path = m[1] }
  /frame_count = / { match($0, /frame_count = ([0-9]+)/, m); cur_fc = m[1] }
  /^\s+\},?$/ {
    if (cur_path != "" && cur_fc != "") print cur_path " " cur_fc
    cur_path = ""; cur_fc = ""
  }
' "$ASSETS" > "$TMP/asset_frame_counts"

# Build character -> sprite_table map (from canon.animation_names)
awk '
  /^canon\.animation_names = {/ { in_an = 1; next }
  in_an && /^}/ { in_an = 0 }
  in_an && /^    [a-z0-9_]+ = \{/ {
    match($0, /^    ([a-z0-9_]+)/, m); cur_aid = m[1]; cur_char = ""; cur_st = ""; next
  }
  in_an && /character = "/ { match($0, /character = "([^"]+)"/, m); cur_char = m[1] }
  in_an && /sprite_table = "/ { match($0, /sprite_table = "([^"]+)"/, m); cur_st = m[1] }
  in_an && /^    \},?$/ {
    if (cur_aid != "" && cur_char != "" && cur_st != "") print cur_char " " cur_st
    cur_aid = ""; cur_char = ""; cur_st = ""
  }
' "$CANON" | sort -u > "$TMP/char_sprite_tables"

violations=""
# Walk animations.lua per character
awk '
  /^local animations = {/ { in_a = 1; next }
  in_a && /^}/ { in_a = 0 }
  in_a && /^    [a-z0-9_]+ = \{/ {
    match($0, /^    ([a-z0-9_]+)/, m); char = m[1]; state = ""; next
  }
  in_a && /^        [a-z0-9_]+ = \{/ {
    match($0, /^        ([a-z0-9_]+)/, m); state = m[1]; in_frames = 0; next
  }
  in_a && /^            frames = \{/ { in_frames = 1; next }
  in_a && in_frames && /^            \}/ { in_frames = 0; next }
  in_a && in_frames && /^\s+[0-9]+,?\s*$/ {
    n = $0; gsub(/[^0-9]/, "", n)
    if (n != "") print char " " state " " n
  }
' "$ANIMATIONS" > "$TMP/anim_frames"

while IFS=' ' read -r char state n; do
  # Find sprite_table for this character
  st=$(grep -E "^${char} " "$TMP/char_sprite_tables" | head -1 | awk '{print $2}')
  if [ -z "$st" ]; then
    # No sprite_table declared (e.g. 'system' fake-character) — skip
    continue
  fi
  fc=$(grep -E "^${st} " "$TMP/asset_frame_counts" | head -1 | awk '{print $2}')
  if [ -z "$fc" ]; then
    violations="${violations}\n  [check5 missing-asset] animations.${char}.${state} references sprite_table '$st' with no matching assets.lua entry"
    continue
  fi
  if [ "$n" -gt "$fc" ]; then
    violations="${violations}\n  [check5 frame-out-of-range] animations.${char}.${state} frame ${n} > asset '${st}'.frame_count (${fc})"
  fi
done < "$TMP/anim_frames"
if [ -n "$violations" ]; then echo -e "FAIL check5 (animation frame out of range):${violations}"; note_fail "check5"; fi

# ============================================================================
# CHECK 6 — dialogue speaker resolves in canon.characters OR is system/newb literal
# ============================================================================
violations=""
while IFS=' ' read -r did speaker; do
  case "$speaker" in
    system|newb) continue ;;
  esac
  if ! grep -qx "$speaker" "$TMP/canon_characters"; then
    violations="${violations}\n  [check6 missing-speaker] dialogue '$did' speaker '$speaker' not in canon.characters"
  fi
done < "$TMP/dialogue_pairs"
if [ -n "$violations" ]; then echo -e "FAIL check6 (missing dialogue speaker):${violations}"; note_fail "check6"; fi

# ============================================================================
# CHECK 7 — required_flags + sets_flags references declared in canon.state_flags
# ============================================================================
violations=""
for sf in "$TMP"/scene_*; do
  [ -f "$sf" ] || continue
  sid=$(grep -E '^\s+id = "' "$sf" | head -1 | sed -E 's/.*id = "([^"]+)".*/\1/')
  for flag in $(list_block "$sf" "required_flags") $(list_block "$sf" "sets_flags"); do
    if ! grep -qx "$flag" "$TMP/canon_state_flags"; then
      violations="${violations}\n  [check7 undeclared-flag] continuity scene '$sid' references flag '$flag' not in canon.state_flags"
    fi
  done
done
if [ -n "$violations" ]; then echo -e "FAIL check7 (undeclared state flag):${violations}"; note_fail "check7"; fi

# ============================================================================
# CHECK 8 — every transitions_to[] target is itself a scene in canon.scenes
# ============================================================================
violations=""
for sf in "$TMP"/scene_*; do
  [ -f "$sf" ] || continue
  sid=$(grep -E '^\s+id = "' "$sf" | head -1 | sed -E 's/.*id = "([^"]+)".*/\1/')
  for target in $(list_block "$sf" "transitions_to"); do
    if ! grep -qx "$target" "$TMP/canon_scenes"; then
      violations="${violations}\n  [check8 invalid-transition] continuity scene '$sid' transitions_to '$target' not in canon.scenes"
    fi
  done
done
if [ -n "$violations" ]; then echo -e "FAIL check8 (invalid transition target):${violations}"; note_fail "check8"; fi

# ============================================================================
# CHECK 9 — canon.objects[].launches (when non-nil) is in canon.scenes
# ============================================================================
violations=""
while IFS= read -r target; do
  [ -z "$target" ] && continue
  if ! grep -qx "$target" "$TMP/canon_scenes"; then
    violations="${violations}\n  [check9 launches-no-scene] some canon.objects[].launches '$target' not in canon.scenes"
  fi
done < "$TMP/object_launches"
if [ -n "$violations" ]; then echo -e "FAIL check9 (object launches no scene):${violations}"; note_fail "check9"; fi

# ============================================================================
if [ "$fail" -eq 0 ]; then
  echo "OK validate_continuity: 9/9 canon graph checks passed."
  exit 0
else
  echo ""
  echo "validate_continuity FAILED:${failed_checks}"
  exit 1
fi
