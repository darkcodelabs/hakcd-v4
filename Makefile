# Makefile for hakcd-v4
#
# Wraps pdc with the asset validator as a pre-compile gate. Every PNG
# under source/ is checked for 1-bit + outline + silhouette dump before
# pdc runs. Bad asset short-circuits the build.
#
# Targets:
#   make            -> build/hakcd.pdx
#   make validate   -> run the validator over every source PNG, no pdc
#   make silhouettes-> regenerate silhouette dumps for manual review
#   make clean      -> wipe build/

PDC := /home/hakcer/PlaydateSDK/bin/pdc
PDX := build/hakcd.pdx
SRC_DIR := source

# All PNGs under source/ (recursive), excluding vendored libraries.
# libraries/ ships third-party assets (NobleRobotLogo etc.) outside our
# authored boundary — trust them, don't gate.
ASSETS := $(shell find $(SRC_DIR) -name '*.png' -type f -not -path '$(SRC_DIR)/libraries/*' 2>/dev/null)

# One sentinel marker per validated asset
VALIDATED := $(ASSETS:%=build/.validated/%.ok)

# Canon graph validator (Phase 7) — single sentinel re-triggered by any
# change under source/data/*.lua. Cheap to run, blocks pdc on drift.
CANON_DATA := $(wildcard $(SRC_DIR)/data/*.lua)
CANON_SENTINEL := build/.validated/.canon-validated.ok

# Visual contract validator (Phase V3) — parses source/data/visual_spec.lua,
# checks art_status / readability / dimension / placeholder rules.
# WARN-only below pdxinfo 0.2.0, FAIL past gate. Exits 0 on warn, non-zero on
# fail. Block pdc on fail.
VISUAL_SPEC := $(SRC_DIR)/data/visual_spec.lua
VISUAL_SENTINEL := build/.validated/.visuals-validated.ok

.PHONY: all validate validate-canon validate-visuals silhouettes clean

all: $(PDX)

# Build target — every asset must pass validation, canon graph must pass,
# and the visual contract must pass before pdc runs.
$(PDX): $(VALIDATED) validate-canon validate-visuals
	@rm -rf $(PDX)
	@mkdir -p build
	$(PDC) $(SRC_DIR) $(PDX)

# Per-asset validation. Touches a sentinel under build/.validated/ so we
# don't re-validate unchanged PNGs on subsequent builds.
build/.validated/%.ok: %
	@mkdir -p $(dir $@)
	@./tools/asset_validator.sh $< && touch $@

# Validate without building
validate: $(VALIDATED) validate-canon validate-visuals
	@echo "All $(words $(ASSETS)) PNGs valid."

# Canon graph validation (Phase 7) — fails build on continuity / id-graph drift.
validate-canon: $(CANON_SENTINEL)

$(CANON_SENTINEL): $(CANON_DATA) tools/canon/validate_continuity.sh
	@mkdir -p $(dir $@)
	@./tools/canon/validate_continuity.sh && touch $@

# Visual contract validation (Phase V3) — parses visual_spec.lua, fails build
# on placeholders past pdxinfo 0.2.0; WARN-only below the gate.
validate-visuals: $(VISUAL_SENTINEL)

$(VISUAL_SENTINEL): $(VISUAL_SPEC) tools/canon/validate_visuals.sh
	@mkdir -p $(dir $@)
	@./tools/canon/validate_visuals.sh && touch $@

# Force-regenerate silhouettes (for manual review pass)
silhouettes:
	@rm -rf build/silhouettes build/.validated
	@$(MAKE) validate
	@echo ""
	@echo "Silhouette previews dumped to build/silhouettes/"
	@echo "Eyeball-check for cabinet-vs-server-rack collisions."

clean:
	rm -rf build
