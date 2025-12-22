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

1.  **Prerequisite Check**: Verifies that OpenSim has been acquired and incubated (`vivarium/opensim-core-0.9.3/bin`) and that Mimic has been built (`vivarium/mimic`).
2.  **Configuration Injection**:
    *   Copies example configuration files (`OpenSim.ini`, etc.) if missing.
    *   Injects a standard test configuration (Estate: "My Estate", Owner: "Test User", Password: "password") to ensure the client can log in.
3.  **Clean Slate**: Removes logs (`encounter.log`, `opensim.log`) and database files (`OpenSim.db`) from previous runs to prevent false positives.
4.  **Orchestration**:
    *   Starts `OpenSim.dll` in the background (redirecting output to `opensim.log`).
    *   Waits for the server to stabilize.
    *   Launches `Mimic.dll` in `success` mode.
5.  **Forensic Verification**:
    *   Parses the resulting `vivarium/encounter.log`.
    *   Scans for "irrefutable observational evidence" of success:
        *   `[CLIENT] [LOGIN] SUCCESS`
        *   `[CLIENT] [UDP] CONNECTED`
6.  **Teardown**: Terminates the OpenSim process.

### Manual Usage

You can also run Mimic manually against a running server:

```bash
# From the repository root, assuming substrate is set up
export DOTNET_ROOT=$(./instruments/substrate/ensure_dotnet.sh)
export PATH=$DOTNET_ROOT:$PATH

cd vivarium/mimic
dotnet Mimic.dll --mode <mode> --user <Firstname> --password <password>
```

**Modes:**
*   `success`: Standard login and connection.
*   `rejection`: Attempts login with an incorrect password.
*   `ghost`: Logins and immediately exits (testing zombie session handling).
*   `wallflower`: Connects but suppresses heartbeat/pings (testing timeout handling).
