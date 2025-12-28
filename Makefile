# Naturalist Observatory Makefile
# ===============================
# A simple harness for the Naturalist Observatory workflow.

# Configuration
# -------------
SCENARIO ?= standard
SCENARIO_PATH = observatory/scenarios/$(SCENARIO).md
VIVARIUM = vivarium
OPENSIM_CORE_DIR = $(VIVARIUM)/opensim-core-0.9.3
OPENSIM_NGC_DIR = $(VIVARIUM)/opensim-ngc-0.9.3
LIBREMETAVERSE_DIR = $(VIVARIUM)/libremetaverse-2.0.0.278

# Default Target
# --------------
.PHONY: all
all: help

.PHONY: help
help:
	@echo "Naturalist Observatory Harness"
	@echo "------------------------------"
	@echo "Build Targets:"
	@echo "  make opensim-core    : Acquire and incubate OpenSim Core (0.9.3)"
	@echo "  make opensim-ngc     : Acquire and incubate OpenSim NGC (Next Gen)"
	@echo "  make libremetaverse  : Acquire and incubate LibreMetaverse"
	@echo "  make benthic         : Build Benthic instrument (Deep Sea Variant)"
	@echo "  make mimic           : Build Mimic instrument"
	@echo "  make sequencer       : Build Sequencer instrument"
	@echo "  make instruments     : Build all instruments (Mimic + Sequencer)"
	@echo "  make observatory     : Full build (OpenSim Core + Instruments)"
	@echo ""
	@echo "Run Targets:"
	@echo "  make observations    : Run encounter and generate dailies (SCENARIO=$(SCENARIO))"
	@echo ""
	@echo "Cleanup Targets:"
	@echo "  make reify-opensim-core : Surgical reset for OpenSim Core"
	@echo "  make reify-opensim-ngc  : Surgical reset for OpenSim NGC"
	@echo "  make reify-libremetaverse : Surgical reset for LibreMetaverse"
	@echo "  make reify-benthic      : Re-acquire and incubate Benthic"
	@echo "  make reset-observations : Remove encounter logs and dailies"
	@echo "  make reset-opensim      : Remove OpenSim logs and observatory data"
	@echo ""
	@echo "Status Targets:"
	@echo "  make status          : Check health/readiness of the ecosystem"
	@echo "  make env             : Check substrate environment configuration"

# Build Targets
# -------------

.PHONY: opensim-core
opensim-core:
	@echo "[MAKE] Acquiring OpenSim Core..."
	@./species/opensim-core/0.9.3/acquire.sh
	@echo "[MAKE] Incubating OpenSim Core..."
	@./species/opensim-core/0.9.3/incubate.sh
	@echo "[MAKE] Generating Invoice..."
	@./instruments/biometrics/generate_invoice.sh $(OPENSIM_CORE_DIR) dotnet

.PHONY: opensim-ngc
opensim-ngc:
	@echo "[MAKE] Acquiring OpenSim NGC..."
	@./species/opensim-ngc/0.9.3/acquire.sh
	@echo "[MAKE] Incubating OpenSim NGC..."
	@./species/opensim-ngc/0.9.3/incubate.sh
	@echo "[MAKE] Generating Invoice..."
	@./instruments/biometrics/generate_invoice.sh $(OPENSIM_NGC_DIR) dotnet

.PHONY: libremetaverse
libremetaverse:
	@echo "[MAKE] Acquiring LibreMetaverse..."
	@./species/libremetaverse/2.0.0.278/acquire.sh
	@echo "[MAKE] Incubating LibreMetaverse..."
	@./species/libremetaverse/2.0.0.278/incubate.sh

.PHONY: mimic
mimic:
	@echo "[MAKE] Building Mimic..."
	@./instruments/mimic/build.sh

.PHONY: benthic
benthic:
	@echo "[MAKE] Building Benthic..."
	@./species/benthic/0.1.0/incubate.sh

.PHONY: reify-benthic
reify-benthic:
	@echo "[MAKE] Reifying Benthic..."
	@./species/benthic/0.1.0/acquire.sh
	@./species/benthic/0.1.0/incubate.sh

.PHONY: sequencer
sequencer:
	@echo "[MAKE] Building Sequencer..."
	@./instruments/sequencer/build.sh

.PHONY: instruments
instruments: mimic sequencer

# Default 'observatory' target uses opensim-core as the baseline
.PHONY: observatory
observatory: instruments opensim-core

# Run Targets
# -----------

.PHONY: observations
observations:
	@echo "[MAKE] Running Observations for $(SCENARIO)..."
	@./observatory/run_encounter.sh $(SCENARIO_PATH)
	@echo "[MAKE] Editing Dailies..."
	@./observatory/editor.py $(SCENARIO_PATH)

.PHONY: run-opensim-core
run-opensim-core:
	@./observatory/boot_opensim.sh

.PHONY: run-libremetaverse
run-libremetaverse:
	@./observatory/boot_libremetaverse.sh

.PHONY: run-mimic
run-mimic:
	@./observatory/boot_mimic.sh

# Cleanup Targets
# ---------------

.PHONY: reify-opensim-core
reify-opensim-core:
	@echo "[MAKE] Reifying OpenSim Core (Surgical Reset)..."
	@if [ -d "$(OPENSIM_CORE_DIR)" ]; then \
		echo "Cleaning $(OPENSIM_CORE_DIR)..."; \
		git -C $(OPENSIM_CORE_DIR) checkout -f; \
		git -C $(OPENSIM_CORE_DIR) clean -fd; \
		./species/opensim-core/0.9.3/incubate.sh; \
	else \
		echo "OpenSim Core not found. Running normal acquisition."; \
		make opensim-core; \
	fi

.PHONY: reify-opensim-ngc
reify-opensim-ngc:
	@echo "[MAKE] Reifying OpenSim NGC (Surgical Reset)..."
	@if [ -d "$(OPENSIM_NGC_DIR)" ]; then \
		echo "Cleaning $(OPENSIM_NGC_DIR)..."; \
		git -C $(OPENSIM_NGC_DIR) checkout -f; \
		git -C $(OPENSIM_NGC_DIR) clean -fd; \
		./species/opensim-ngc/0.9.3/incubate.sh; \
	else \
		echo "OpenSim NGC not found. Running normal acquisition."; \
		make opensim-ngc; \
	fi

.PHONY: reify-libremetaverse
reify-libremetaverse:
	@echo "[MAKE] Reifying LibreMetaverse (Surgical Reset)..."
	@if [ -d "$(LIBREMETAVERSE_DIR)" ]; then \
		echo "Cleaning $(LIBREMETAVERSE_DIR)..."; \
		git -C $(LIBREMETAVERSE_DIR) checkout -f; \
		git -C $(LIBREMETAVERSE_DIR) clean -fd; \
		./species/libremetaverse/2.0.0.278/incubate.sh; \
	else \
		echo "LibreMetaverse not found. Running normal acquisition."; \
		make libremetaverse; \
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
	@rm -rf $(OPENSIM_CORE_DIR)/observatory/
	@rm -rf $(OPENSIM_NGC_DIR)/observatory/
	@find $(VIVARIUM) -name "OpenSim.log" -type f -delete
	@echo "Done."

# Status Targets
# --------------

.PHONY: status-opensim-core
status-opensim-core:
	@echo "[STATUS] OpenSim Core:"
	@if [ -d "$(OPENSIM_CORE_DIR)" ]; then \
		echo "  path: $(OPENSIM_CORE_DIR) [FOUND]"; \
	else \
		echo "  path: $(OPENSIM_CORE_DIR) [MISSING]"; \
	fi
	@if [ -f "$(OPENSIM_CORE_DIR)/bin/OpenSim.dll" ]; then \
		echo "  build: $(OPENSIM_CORE_DIR)/bin/OpenSim.dll [FOUND]"; \
	else \
		echo "  build: $(OPENSIM_CORE_DIR)/bin/OpenSim.dll [MISSING]"; \
	fi

.PHONY: status-opensim-ngc
status-opensim-ngc:
	@echo "[STATUS] OpenSim NGC:"
	@if [ -d "$(OPENSIM_NGC_DIR)" ]; then \
		echo "  path: $(OPENSIM_NGC_DIR) [FOUND]"; \
	else \
		echo "  path: $(OPENSIM_NGC_DIR) [MISSING]"; \
	fi
	@if [ -f "$(OPENSIM_NGC_DIR)/build/Release/OpenSim.dll" ]; then \
		echo "  build: $(OPENSIM_NGC_DIR)/build/Release/OpenSim.dll [FOUND]"; \
	else \
		echo "  build: $(OPENSIM_NGC_DIR)/build/Release/OpenSim.dll [MISSING]"; \
	fi

.PHONY: status-libremetaverse
status-libremetaverse:
	@echo "[STATUS] LibreMetaverse:"
	@if [ -d "$(LIBREMETAVERSE_DIR)" ]; then \
		echo "  path: $(LIBREMETAVERSE_DIR) [FOUND]"; \
	else \
		echo "  path: $(LIBREMETAVERSE_DIR) [MISSING]"; \
	fi
	@if [ -f "$(LIBREMETAVERSE_DIR)/DeepSeaClient_Build/bin/Release/net8.0/DeepSeaClient" ] || [ -f "$(LIBREMETAVERSE_DIR)/DeepSeaClient_Build/bin/Release/net8.0/DeepSeaClient.dll" ]; then \
		echo "  build: DeepSeaClient [FOUND]"; \
	else \
		echo "  build: DeepSeaClient [MISSING]"; \
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

.PHONY: env
env:
	@echo "Observatory Environment"
	@echo "-----------------------"
	@bash -c "source instruments/substrate/observatory_env.bash && env | grep -E 'DOTNET_ROOT|DOTNET_CLI_HOME|NUGET_PACKAGES|CARGO_HOME|RUSTUP_HOME|PATH' | sort"

.PHONY: status-old
status-old: status-opensim-core status-opensim-ngc status-instruments status-encounter
	@echo "------------------------------"
	@if [ -f "$(OPENSIM_CORE_DIR)/bin/OpenSim.dll" ] || [ -f "$(OPENSIM_NGC_DIR)/build/Release/OpenSim.dll" ]; then \
		echo "[STATUS] SYSTEM READY"; \
	else \
		echo "[STATUS] SYSTEM INCOMPLETE (No OpenSim available)"; \
	fi
	@echo ""
	@make env

.PHONY: status
status:
	@echo ""
	@echo "--- Naturalist Observatory Status ---"
	@echo ""
	@echo "Specimens:"
	@if [ -f "$(OPENSIM_CORE_DIR)/bin/OpenSim.dll" ]; then \
		echo "  [+] OpenSim Core (Incubated)"; \
	elif [ -d "$(OPENSIM_CORE_DIR)" ]; then \
		echo "  [.] OpenSim Core (Acquired)"; \
	else \
		echo "  [ ] OpenSim Core"; \
	fi
	@if [ -f "$(OPENSIM_NGC_DIR)/build/Release/OpenSim.dll" ]; then \
		echo "  [+] OpenSim NGC (Incubated)"; \
	elif [ -d "$(OPENSIM_NGC_DIR)" ]; then \
		echo "  [.] OpenSim NGC (Acquired)"; \
	else \
		echo "  [ ] OpenSim NGC"; \
	fi
	@if [ -f "$(LIBREMETAVERSE_DIR)/DeepSeaClient_Build/bin/Release/net8.0/DeepSeaClient.dll" ]; then \
		echo "  [+] LibreMetaverse (Incubated)"; \
	elif [ -d "$(LIBREMETAVERSE_DIR)" ]; then \
		echo "  [.] LibreMetaverse (Acquired)"; \
	else \
		echo "  [ ] LibreMetaverse"; \
	fi
	@if [ -f "$(VIVARIUM)/benthic-0.1.0/target/release/deepsea_client" ]; then \
		echo "  [+] Benthic (Incubated)"; \
	elif [ -d "$(VIVARIUM)/benthic-0.1.0" ]; then \
		echo "  [.] Benthic (Acquired)"; \
	else \
		echo "  [ ] Benthic"; \
	fi
	@echo ""
	@echo "Instruments:"
	@if [ -f "$(VIVARIUM)/mimic/Mimic.dll" ]; then \
		echo "  [+] Mimic"; \
	else \
		echo "  [ ] Mimic"; \
	fi
	@if [ -f "$(VIVARIUM)/sequencer/Sequencer.dll" ]; then \
		echo "  [+] Sequencer"; \
	else \
		echo "  [ ] Sequencer"; \
	fi
	@echo ""
	@echo "Substrate:"
	@bash -c "source instruments/substrate/observatory_env.bash; \
	if command -v dotnet >/dev/null 2>&1; then \
		VER=\$$(dotnet --version 2>/dev/null); \
		if [ -n \"\$$VER\" ]; then \
			echo \"  [+] dotnet \$$VER\"; \
		else \
			echo \"  [ ] dotnet (found but error)\"; \
		fi; \
	else \
		echo \"  [ ] dotnet\"; \
	fi; \
	if command -v cargo >/dev/null 2>&1; then \
		VER=\$$(rustc --version 2>/dev/null | awk '{print \$$2}'); \
		if [ -n \"\$$VER\" ]; then \
			echo \"  [+] rust \$$VER\"; \
		else \
			echo \"  [ ] rust (toolchain missing)\"; \
		fi; \
	else \
		echo \"  [ ] rust\"; \
	fi"
	@echo ""
	@echo "Observatory:"
	@if [ -d "$(VIVARIUM)" ]; then \
		USAGE=$$(du -sh $(VIVARIUM) 2>/dev/null | cut -f1); \
		echo "  [+] $(VIVARIUM)/ (size: $$USAGE)"; \
	else \
		echo "  [ ] $(VIVARIUM)/"; \
	fi
	@BRANCH=$$(git branch --show-current); \
	HASH=$$(git rev-parse --short HEAD); \
	if [ -z "$$(git status --porcelain)" ]; then \
		STATUS="clean"; \
	else \
		STATUS="dirty"; \
	fi; \
	echo "  [+] git (branch: $$BRANCH; commit: $$HASH; status: $$STATUS)"
	@echo "-------------------------------------"
