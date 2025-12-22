# Mimic Instrument

**Mimic** is a lightweight, .NET 8-based client instrument designed to interact with Open Simulator (OpenSim) environments. It serves as a controllable "Visitant" (client agent) for verifying server protocols, performing stress tests, and conducting automated "Encounters".

## Overview

Mimic uses the `LibreMetaverse` library to speak the Second Life / OpenSim protocol (LindenUDP). It is designed to be built and run within the project's "Naturalist Observatory" environment, strictly adhering to containment rules (outputting artifacts to `vivarium/`).

## Build Instructions

To build the Mimic instrument:

```bash
./instruments/mimic/build.sh
```

This will:
1.  Initialize the local .NET substrate.
2.  Compile the source code from `src/`.
3.  Output the resulting binary to `vivarium/mimic/Mimic.dll`.

## Usage: The Encounter Protocol (Literate Harness)

To verify the "Mating Rituals" (connection handshake) between an OpenSim specimen and the Mimic instrument, use the automated orchestration script which now invokes "The Director":

```bash
./instruments/mimic/run_encounter.sh
```

This script executes the **Standard Encounter** scenario defined in `instruments/mimic/scenarios/standard.md`.

### The Director & Literate Scenarios

The new harness uses `director.py` to execute "Literate Scenarios" written in Markdown. This allows complex interactions to be defined in a human-readable format.

A scenario file contains fenced code blocks that the Director executes:
*   **`bash`**: Executes shell commands (for setup/cleanup).
*   **`opensim`**: Manages the OpenSim process (start, send commands, terminate).
*   **`cast`**: JSON block defining users to be injected into the database via `Sequencer` and `sqlite3`.
*   **`mimic`**: Spawns or controls a `Mimic` process in REPL mode.
*   **`wait`**: Pauses execution for a specified duration (ms).

### Mimic REPL

The `Mimic.dll` now supports an interactive REPL mode (`--repl`), accepting commands via Standard Input:
*   `LOGIN <First> <Last> <Pass> [URI]`
*   `CHAT <Message>`
*   `REZ` (Creates a primitive object)
*   `WAIT <ms>`
*   `LOGOUT`
*   `EXIT`

### Legacy Usage

You can still run Mimic manually against a running server using the legacy command-line arguments:

```bash
# From the repository root
export DOTNET_ROOT=$(./instruments/substrate/ensure_dotnet.sh)
export PATH=$DOTNET_ROOT:$PATH

# Legacy Mode
./vivarium/mimic/Mimic.dll --user <First> --lastname <Last> --password <Pass> --mode <Mode>
```
