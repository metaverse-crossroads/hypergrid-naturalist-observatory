# Hypergrid Naturalist Observatory

The Hypergrid Naturalist Observatory is a set of instruments and protocols for observing and interacting with OpenSimulator-based virtual environments. It treats the metaverse as a living ecosystem, using "Visitants" (automated client agents) to collect "Field Marks" (observations) from "Territories" (regions).

## Structure

*   `species/`: Configuration and source code for the target environments (e.g., `opensim-core`).
*   `instruments/`: Tools and agents.
    *   `mimic/`: A C# .NET 8 Visitant (client bot) based on LibreMetaverse.
    *   `substrate/`: Setup scripts for the local environment (Rust, .NET).
    *   `narrator/`: Tools for generating narrative logs.
*   `vivarium/`: The working directory for incubated specimens and runtime artifacts.
*   `journals/`: Documentation and logs.

## Usage

### Prerequisites
Ensure you have the required substrate:
```bash
./instruments/substrate/ensure_dotnet.sh
```

### 1. Acquire and Incubate Species
Clone and prepare the target OpenSim version.
```bash
./species/opensim-core/0.9.3/acquire.sh
./species/opensim-core/0.9.3/incubate.sh
```
*Note: `incubate.sh` applies instrumentation patches to the OpenSim source code to enable server-side "Field Marks" (logging).*

### 2. Mimic Instrument (The Visitant)

The `Mimic` instrument is an automated agent that logs into a grid, performs actions, and records observations.

#### Setup
Configure the environment and create necessary test users:
```bash
./instruments/mimic/setup_encounter.sh
```
This script is idempotent and prepares the configuration for the encounter.

#### Running a Single Visitant
To launch a single Visitant instance:
```bash
./instruments/mimic/run_visitant.sh <Firstname> <Lastname> <Password> <HomeURI> [Flags]
```

#### Orchestrating an Encounter
To run a full multi-agent scenario (e.g., two Visitants interacting):
```bash
./instruments/mimic/run_encounter.sh
```
This script handles the lifecycle of the OpenSim server and the Visitants, verifying the interaction via logs.

## Instrumentation Patches

The `species/opensim-core/0.9.3/patches/` directory contains:
*   **Instrumentation:**
    *   `EncounterLogger.patch`: Adds the `EncounterLogger` class.
    *   `LLLoginService.patch`: Logs `VisitantLogin`.
    *   `LLUDPServer.patch`: Logs `UseCircuitCode` (connection attempts).
    *   `LLClientView.patch`: Logs `Chat` from Visitants.
*   **Fixes:**
    *   `VectorRenderModule.patch`: Fixes GDI+ crashes on Linux.
    *   `LocalConsole.patch`: Fixes console input redirection issues.

## Logs
Interaction logs are stored in `vivarium/encounter.log`.
