# Naturalist Observatory: Build & Verification Baseline

This document captures the baseline regression testing strategy for the **Naturalist Observatory** ecosystem. It serves as a low-level starting point for anyone setting up the repository locally, or as a reference point for smoke testing and verifying environment health across supported platforms (Linux, Windows msys git+bash).

Our environment relies on the `vivarium` workspace, isolating system dependencies such as specific `dotnet` and `rust` toolchains so that builds remain repeatable and don't pollute your host environment.

## 1. Core Platform Support
Recent updates have brought **Windows msys git+bash** platform support into the mix. For the most part, it shares the exact same bash and Makefile logic as Linux, requiring only minor OS-specific path tweaks in certain scripts.

## 2. Regression Testing / Smoke Verification

A full baseline verification pass consists of three main commands. Running these confirms that the entire ecosystem (tools, dependencies, compilation, and networking simulation) works correctly.

> **Note:** If you run into environment reset issues or see "canary" warnings, prefix your commands with `source bin/canary` once per bash session, and then prefix `make` with `canary` (e.g., `canary make observatory`).

### Step 1: Observatory Core & Instruments
Acquire, patch, and incubate `opensim-core` (the default simulant), along with our primary instruments (`mimic` and `sequencer`).

```bash
make observatory
```

*This step automatically provisions the correct `.NET` SDK in the `vivarium/substrate`, downloads OpenSim 0.9.3, applies necessary patches, and injects runtime plugins.*

**Experimental Addins:** As part of the `opensim-core-0.9.3` build, an experimental `WebRTCSIPSorcery` addin support is prototyped. The `oscsc.bash` wrapper is used to one-shot compile standalone `.cs` files into `.dll` addins that OpenSim loads at runtime.

### Step 2: System Observations
Run a full encounter simulation using the baseline scenario to ensure the server and instruments can interact successfully.

```bash
make observations
```

*You should see no errors anywhere during execution, and the daily logs output should report MISSION SUCCESS.*

### Step 3: LibreMetaverse Validation
Verify that the `LibreMetaverse` dependency builds correctly. Recent versions had issues on Windows with `dotnet 8.0.419`; the `.csproj` and `Build.props` workarounds are intended to maintain cross-platform support with older and current `.NET 8.x.y` versions on Linux and Windows.

Provision a specific version of LibreMetaverse:

```bash
python3 observatory/stagehand.py provision libremetaverse-2.5.7.90
```

Verify that the standalone executable was compiled successfully:

```bash
vivarium/libremetaverse-2.5.7.90/DeepSeaClient_Project/bin/Release/net8.0/DeepSeaClient --version
```
*(Expected Output: `DeepSeaClient 2.5.7`)*

---

## 3. Experimental Specimens

Beyond the standard stable baseline above, the ecosystem includes several experimental specimens and branches. These may be unstable but are available for advanced observation and development.

You can provision and test these similarly:

*   **`make opensim-ngc`**: Next Gen OpenSim (Acquires and incubate OpenSim NGC).
*   **`make opensim-core-master`**: The bleeding-edge development branch of OpenSim Core.
*   **`make benthic`**: Build the experimental Benthic instrument (Deep Sea Variant written in Rust).
