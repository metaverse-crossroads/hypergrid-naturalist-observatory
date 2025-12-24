# Naturalist Observatory Makefile
# ===============================
# A simple harness for the Naturalist Observatory workflow.

# Configuration
# -------------
SCENARIO ?= standard
SCENARIO_PATH = observatory/scenarios/$(SCENARIO).md
VIVARIUM = vivarium
OPENSIM_DIR = $(VIVARIUM)/opensim-core-0.9.3

# Default Target
# --------------
.PHONY: help
help:
	@echo "Naturalist Observatory Harness"
	@echo "------------------------------"
	@echo "Build Targets:"
	@echo "  make opensim        : Acquire and incubate OpenSim 0.9.3"
	@echo "  make mimic          : Build Mimic instrument"
	@echo "  make sequencer      : Build Sequencer instrument"
	@echo "  make instruments    : Build all instruments (Mimic + Sequencer)"
	@echo "  make observatory    : Full build (OpenSim + Instruments)"
	@echo ""
	@echo "Run Targets:"
	@echo "  make observations   : Run encounter and generate dailies (SCENARIO=$(SCENARIO))"
	@echo ""
	@echo "Cleanup Targets:"
	@echo "  make reify-opensim  : Git clean OpenSim source and re-incubate (Surgical Reset)"
	@echo "  make reset-observations : Remove encounter logs and dailies"
	@echo "  make reset-opensim  : Remove OpenSim logs and observatory data"
	@echo ""
	@echo "Status Targets:"
	@echo "  make status         : Check health/readiness of the ecosystem"

# Build Targets
# -------------

.PHONY: opensim
opensim:
	@echo "[MAKE] Acquiring OpenSim..."
	@./species/opensim-core/0.9.3/acquire.sh
	@echo "[MAKE] Incubating OpenSim..."
	@./species/opensim-core/0.9.3/incubate.sh
	@echo "[MAKE] Generating Invoice..."
	@./instruments/biometrics/generate_invoice.sh $(OPENSIM_DIR) dotnet

.PHONY: mimic
mimic:
	@echo "[MAKE] Building Mimic..."
	@./instruments/mimic/build.sh

.PHONY: sequencer
sequencer:
	@echo "[MAKE] Building Sequencer..."
	@./instruments/sequencer/build.sh

.PHONY: instruments
instruments: mimic sequencer

.PHONY: observatory
observatory: instruments opensim

# Run Targets
# -----------

.PHONY: observations
observations:
	@echo "[MAKE] Running Observations for $(SCENARIO)..."
	@./observatory/run_encounter.sh $(SCENARIO_PATH)
	@echo "[MAKE] Editing Dailies..."
	@./observatory/editor.py $(SCENARIO_PATH)

# Cleanup Targets
# ---------------

.PHONY: reify-opensim
reify-opensim:
	@echo "[MAKE] Reifying OpenSim (Surgical Reset)..."
	@if [ -d "$(OPENSIM_DIR)" ]; then \
		echo "Cleaning $(OPENSIM_DIR)..."; \
		git -C $(OPENSIM_DIR) clean -fd; \
		./species/opensim-core/0.9.3/incubate.sh; \
	else \
		echo "OpenSim directory not found. Running normal acquisition."; \
		make opensim; \
	fi

.PHONY: reset-observations
reset-observations:
	@echo "[MAKE] Resetting Observations..."
	@rm -f $(VIVARIUM)/encounter.*.log
	@rm -f $(VIVARIUM)/encounter.*.json
	@echo "Done."

.PHONY: reset-opensim
reset-opensim:
	@echo "[MAKE] Resetting OpenSim State..."
	@rm -rf $(OPENSIM_DIR)/observatory/
	@find $(OPENSIM_DIR) -name "*.log" -type f -delete
	@echo "Done."

# Status Targets
# --------------

.PHONY: status-opensim
status-opensim:
	@echo "[STATUS] OpenSim:"
	@if [ -d "$(OPENSIM_DIR)" ]; then \
		echo "  path: $(OPENSIM_DIR) [FOUND]"; \
	else \
		echo "  path: $(OPENSIM_DIR) [MISSING]"; \
	fi
	@if [ -f "$(OPENSIM_DIR)/bin/OpenSim.dll" ]; then \
		echo "  build: $(OPENSIM_DIR)/bin/OpenSim.dll [FOUND]"; \
	else \
		echo "  build: $(OPENSIM_DIR)/bin/OpenSim.dll [MISSING]"; \
	fi
	@if pgrep -f "OpenSim.dll" > /dev/null; then \
		echo "  process: RUNNING"; \
	else \
		echo "  process: NOT RUNNING"; \
	fi

.PHONY: status-mimic
status-mimic:
	@echo "[STATUS] Mimic:"
	@if [ -f "$(VIVARIUM)/mimic/Mimic.dll" ]; then \
		echo "  build: $(VIVARIUM)/mimic/Mimic.dll [FOUND]"; \
	else \
		echo "  build: $(VIVARIUM)/mimic/Mimic.dll [MISSING]"; \
	fi

.PHONY: status-instruments
status-instruments: status-mimic
	@echo "[STATUS] Sequencer:"
	@if [ -f "$(VIVARIUM)/sequencer/Sequencer.dll" ]; then \
		echo "  build: $(VIVARIUM)/sequencer/Sequencer.dll [FOUND]"; \
	else \
		echo "  build: $(VIVARIUM)/sequencer/Sequencer.dll [MISSING]"; \
	fi

.PHONY: status-encounter
status-encounter:
	@echo "[STATUS] Encounter ($(SCENARIO)):"
	@if ls $(VIVARIUM)/encounter.$(SCENARIO).*.log 1> /dev/null 2>&1; then \
		echo "  logs: PRESENT (Dirty)"; \
	else \
		echo "  logs: CLEAN"; \
	fi

.PHONY: status
status: status-opensim status-instruments status-encounter
	@echo "------------------------------"
	@if [ -f "$(OPENSIM_DIR)/bin/OpenSim.dll" ] && [ -f "$(VIVARIUM)/mimic/Mimic.dll" ]; then \
		echo "[STATUS] SYSTEM READY"; \
	else \
		echo "[STATUS] SYSTEM INCOMPLETE"; \
	fi
