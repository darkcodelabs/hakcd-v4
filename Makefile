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

.PHONY: all validate silhouettes clean

all: $(PDX)

# Build target — depends on every asset passing validation first
$(PDX): $(VALIDATED)
	@rm -rf $(PDX)
	@mkdir -p build
	$(PDC) $(SRC_DIR) $(PDX)

# Per-asset validation. Touches a sentinel under build/.validated/ so we
# don't re-validate unchanged PNGs on subsequent builds.
build/.validated/%.ok: %
	@mkdir -p $(dir $@)
	@./tools/asset_validator.sh $< && touch $@

# Validate without building
validate: $(VALIDATED)
	@echo "All $(words $(ASSETS)) PNGs valid."

# Force-regenerate silhouettes (for manual review pass)
silhouettes:
	@rm -rf build/silhouettes build/.validated
	@$(MAKE) validate
	@echo ""
	@echo "Silhouette previews dumped to build/silhouettes/"
	@echo "Eyeball-check for cabinet-vs-server-rack collisions."

clean:
	rm -rf build
