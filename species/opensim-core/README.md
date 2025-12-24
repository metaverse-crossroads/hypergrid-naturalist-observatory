# Species: OpenSim Core

**Classification:** Server Application / Grid
**Role:** The Range

This directory contains the DNA required to reconstruct an OpenSim Grid Server.

## Subspecies
* **0.9.3**: The standard robust server distribution.

## Artifacts
* `acquire.sh`: Clones the required repositories (OpenSim, LibreMetaverse).
* `incubate.sh`: Compiles the Specimen.
* `instrument_encounter.patch`: Injects the `EncounterLogger` to observe connection sequences.
* `LocalConsoleRedirect.patch`: Modifies `LocalConsole.cs` to allow `director.py` to drive the console via standard input (stdin) even when input is technically redirected.

## Journal
* **2025-02-14**: Integrated Stdio-REPL support via `LocalConsoleRedirect.patch`, enabling Literate Scenarios to issue console commands directly.
