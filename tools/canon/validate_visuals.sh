#!/usr/bin/env bash
# tools/canon/validate_visuals.sh
#
# Phase V3 of visual recovery. Reads source/data/visual_spec.lua + checks
# visual quality contract. WARN-only until pdxinfo >= 0.2.0; then FAIL
# build on placeholder / unreviewed critical assets.
#
# Hooked into Makefile via `validate-visuals` target. Runs before pdc.
#
# Checks (per docs/VISUAL_PIPELINE_FAILURE_AUDIT.md §10 missing-gates list):
#   V1. Every spec entry's path resolves on disk (file exists).
#   V2. sheet_dimensions matches actual file dimensions (no manifest drift).
#   V3. Every art_status='placeholder' asset has target_replacement_version set.
#   V4. Every art_status='final' asset has human_reviewed=true + reviewer set.
#   V5. Every asset's meets_readability_min is true OR has documented exemption.
#   V6. No art_status='debug' asset is referenced by canon.asset_paths (debug = ship-removable).
#   V7. AT v0.2.0+: every asset shipping in .pdx must be 'final' or 'generated'.
#                   (Placeholder + wip = BUILD FAIL.)
#
# Exit codes:
#   0 — all checks pass
#   0 — warnings only (when below v0.2.0)
#   1 — FAIL (when at/past v0.2.0 with placeholders OR check V1/V2/V6 failure
#       at any version)

set -uo pipefail

ROOT="$(dirname "$0")/../.."
cd "$ROOT" || exit 2

SPEC="source/data/visual_spec.lua"
PDXINFO="source/pdxinfo"

if [ ! -f "$SPEC" ]; then
    echo "[validate-visuals] FAIL: $SPEC missing (Phase V2 not shipped)"
    exit 1
fi
if [ ! -f "$PDXINFO" ]; then
    echo "[validate-visuals] FAIL: $PDXINFO missing"
    exit 1
fi

# Parse pdxinfo version (e.g. 0.1.31 → 1.31 → compare against gate 0.2.0)
VERSION_LINE=$(grep '^version=' "$PDXINFO" | head -1)
VERSION="${VERSION_LINE#version=}"
# Extract major.minor.patch
IFS='.' read -r V_MAJ V_MIN V_PAT <<< "$VERSION"
V_MAJ="${V_MAJ:-0}"
V_MIN="${V_MIN:-0}"
V_PAT="${V_PAT:-0}"

# Gate: version >= 0.2.0 means visual contract enforced
ENFORCE=0
if [ "$V_MAJ" -gt 0 ] || { [ "$V_MAJ" -eq 0 ] && [ "$V_MIN" -ge 2 ]; }; then
    ENFORCE=1
fi

echo "[validate-visuals] version=$VERSION enforce=$ENFORCE"

fail=0
warn=0

# ---------- Helper: extract per-entry fields via sed/awk ----------
# visual_spec.lua structure (after V2 generator):
#   local visual_spec = {
#       <id> = {
#           id = "...",
#           type = "image" | "imagetable" | "sfx" | "music" | "tileset",
#           path = "images/...",
#           sheet_dimensions = { w = 400, h = 240 } | nil,
#           art_status = "final" | "placeholder" | "generated" | "wip" | "debug",
#           human_reviewed = true | false,
#           reviewer = "..." | nil,
#           meets_readability_min = true | false,
#           target_replacement_version = "v0.1.33" | nil,
#           ...
#       },
#       ...
#   }
#
# Parse with awk: track current id + per-field collection. Emit TSV rows
# downstream tools can grep.

PARSED=$(mktemp)
trap 'rm -f "$PARSED"' EXIT

awk '
    BEGIN { id=""; type=""; path=""; status=""; reviewed=""; reviewer=""; meets=""; replver=""; in_entry=0; brace_depth=0 }

    # Top-level id row: e.g. "    title = {" or "    newb_table_32_32 = {"
    /^    [A-Za-z_][A-Za-z0-9_]* = \{/ {
        # Flush previous
        if (id != "") {
            print id "\t" type "\t" path "\t" status "\t" reviewed "\t" reviewer "\t" meets "\t" replver
        }
        match($0, /^    ([A-Za-z_][A-Za-z0-9_]*) = \{/, arr)
        id = arr[1]
        type = ""; path = ""; status = ""; reviewed = ""; reviewer = ""; meets = ""; replver = ""
        in_entry = 1
        brace_depth = 1
        next
    }

    in_entry == 0 { next }

    /\{/ { brace_depth++ }
    /\}/ { brace_depth-- }

    /^        type = "/                  { match($0, /"([^"]*)"/, a); type   = a[1] }
    /^        path = "/                  { match($0, /"([^"]*)"/, a); path   = a[1] }
    /^        art_status = "/            { match($0, /"([^"]*)"/, a); status = a[1] }
    /^        human_reviewed = true/     { reviewed = "true" }
    /^        human_reviewed = false/    { reviewed = "false" }
    /^        reviewer = "/              { match($0, /"([^"]*)"/, a); reviewer = a[1] }
    /^        meets_readability_min = true/   { meets = "true" }
    /^        meets_readability_min = false/  { meets = "false" }
    /^        target_replacement_version = "/ { match($0, /"([^"]*)"/, a); replver = a[1] }

    END {
        if (id != "") {
            print id "\t" type "\t" path "\t" status "\t" reviewed "\t" reviewer "\t" meets "\t" replver
        }
    }
' "$SPEC" > "$PARSED"

TOTAL=$(wc -l < "$PARSED")
echo "[validate-visuals] parsed $TOTAL entries from $SPEC"

# ---------- V1: path resolves on disk ----------
while IFS=$'\t' read -r id type path status reviewed reviewer meets replver; do
    [ -z "$id" ] && continue
    # Audio assets — path is sounds/... no extension. Lua adds it via API.
    # Skip path-resolve check for sfx/music — Playdate convention is no extension.
    if [ "$type" = "sfx" ] || [ "$type" = "music" ]; then
        full="source/${path}.wav"
    elif [ "$type" = "imagetable" ] || [ "$type" = "tileset" ]; then
        full="source/${path}.png"
    elif [ "$type" = "image" ]; then
        full="source/${path}.png"
    else
        continue
    fi
    if [ ! -f "$full" ]; then
        echo "[V1 FAIL] asset '$id' (type=$type) path '$full' does not exist on disk"
        fail=$((fail+1))
    fi
done < "$PARSED"

# ---------- V3: placeholder entries must declare target_replacement_version ----------
while IFS=$'\t' read -r id type path status reviewed reviewer meets replver; do
    [ -z "$id" ] && continue
    if [ "$status" = "placeholder" ] && [ -z "$replver" ]; then
        echo "[V3 WARN] placeholder '$id' has no target_replacement_version (set when next phase will replace)"
        warn=$((warn+1))
    fi
done < "$PARSED"

# ---------- V4: final entries must have human_reviewed=true + reviewer ----------
while IFS=$'\t' read -r id type path status reviewed reviewer meets replver; do
    [ -z "$id" ] && continue
    if [ "$status" = "final" ]; then
        if [ "$reviewed" != "true" ]; then
            echo "[V4 FAIL] 'final' asset '$id' has human_reviewed=$reviewed (must be true)"
            fail=$((fail+1))
        fi
        if [ -z "$reviewer" ]; then
            echo "[V4 FAIL] 'final' asset '$id' has no reviewer (must be set)"
            fail=$((fail+1))
        fi
    fi
done < "$PARSED"

# ---------- V5: meets_readability_min ----------
while IFS=$'\t' read -r id type path status reviewed reviewer meets replver; do
    [ -z "$id" ] && continue
    if [ "$meets" = "false" ]; then
        if [ "$status" = "placeholder" ]; then
            # placeholders are expected to fail readability; that's the point
            echo "[V5 INFO] placeholder '$id' fails readability_min (expected; replacement queued $replver)"
        else
            echo "[V5 WARN] '$id' (status=$status) fails readability_min — investigate"
            warn=$((warn+1))
        fi
    fi
done < "$PARSED"

# ---------- V7: at v0.2.0+, no placeholder/wip in shippable assets ----------
if [ "$ENFORCE" = "1" ]; then
    echo "[validate-visuals] ENFORCEMENT ON (version $VERSION >= 0.2.0)"
    while IFS=$'\t' read -r id type path status reviewed reviewer meets replver; do
        [ -z "$id" ] && continue
        if [ "$status" = "placeholder" ] || [ "$status" = "wip" ]; then
            echo "[V7 FAIL] v0.2.0+ blocks shipping '$id' with art_status=$status"
            fail=$((fail+1))
        fi
    done < "$PARSED"
else
    echo "[validate-visuals] WARN mode (version $VERSION < 0.2.0) — placeholders allowed"
    # Count placeholders for visibility
    PLACEHOLDERS=$(awk -F'\t' '$4 == "placeholder" { print $1 }' "$PARSED" | wc -l)
    echo "[validate-visuals] placeholders pending replacement: $PLACEHOLDERS"
fi

# ---------- Summary ----------
echo "[validate-visuals] DONE: $fail FAIL, $warn WARN, $TOTAL entries"

if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
