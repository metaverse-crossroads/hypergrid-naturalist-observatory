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

## Usage: The Encounter Protocol

To verify the "Mating Rituals" (connection handshake) between an OpenSim specimen and the Mimic instrument, use the automated orchestration script:

```bash
./instruments/mimic/run_encounter.sh
```

### What `run_encounter.sh` does:

1.  **Prerequisite Check**: Verifies that OpenSim has been acquired and incubated and that Mimic has been built.
2.  **Configuration Injection**:
    *   Creates a clean Observatory environment in `vivarium/opensim-core-0.9.3/observatory`.
    *   Configures `Regions.ini` and `encounter.ini`.
3.  **Clean Slate**: Removes logs and database files to ensure a fresh start.
4.  **World Generation**:
    *   Starts OpenSim briefly to initialize empty SQLite databases.
    *   Runs `instruments/mimic/setup_world.sh` to inject world data (Users, Prims, Inventory) via SQL.
5.  **Multi-Visitant Orchestration**:
    *   Starts `OpenSim.dll` in the background.
    *   Launches **two** parallel Visitant instances (`Visitant One` and `Visitant Two`) using `instruments/mimic/run_visitant.sh`.
6.  **Forensic Verification**:
    *   Parses `vivarium/encounter.log`.
    *   Verifies that **both** Visitants successfully logged in and established UDP connections.
7.  **Teardown**: Terminates the OpenSim process.

### Helper Scripts

*   **`setup_world.sh`**: Generates SQL data using `Mimic.dll --mode gen-data` and injects it into OpenSim's SQLite databases to populate users (Visitant One/Two) and objects.
*   **`run_visitant.sh`**: Wrapper script to launch a single Mimic instance with specific credentials.

### Manual Usage

You can run Mimic manually against a running server:

```bash
# From the repository root
export DOTNET_ROOT=$(./instruments/substrate/ensure_dotnet.sh)
export PATH=$DOTNET_ROOT:$PATH

./instruments/mimic/run_visitant.sh --user <Firstname> --lastname <Lastname> --password <password> --mode <mode>
```

**Modes:**
*   `success`: Standard login and connection.
*   `rejection`: Attempts login with an incorrect password.
*   `ghost`: Logins and immediately exits.
*   `wallflower`: Connects but suppresses heartbeat/pings.
*   `gen-data`: Outputs SQL statements for world generation (used by `setup_world.sh`).
