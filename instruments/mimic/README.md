# Mimic Instrument

**Mimic** is a lightweight, .NET 8-based client instrument designed to interact with Open Simulator (OpenSim) environments. It serves as a controllable "Visitant" (client agent) for verifying server protocols, performing stress tests, and conducting automated "Encounters".

## Overview

Mimic uses the `LibreMetaverse` library to speak the Second Life / OpenSim protocol (LindenUDP). It is designed to be built and run within the project's "Naturalist Observatory" environment, strictly adhering to containment rules (outputting artifacts to `vivarium/`).

## The Logger (JSON Fragment Ritual)

Mimic uses a structured JSON logging format to facilitate automated verification.

Schema:
```json
{ "at": "ISO_TIMESTAMP", "via": "SIDE", "sys": "SYSTEM", "sig": "SIGNAL", "val": "PAYLOAD" }
```

*   **at**: Timestamp (UTC ISO 8601)
*   **via**: Observer (`Visitant` or `Ranger`)
*   **sys**: Component (`Login`, `UDP`, `Sight`, `Chat`, etc.)
*   **sig**: Signal (`Connected`, `Heard`, `Rez`, `Success`, etc.)
*   **val**: Payload details

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

**Note:** The encounter orchestration framework (Director, Scenarios) has moved to the `observatory/` directory.

Please refer to `observatory/README.md` for instructions on how to run automated encounters.

### Mimic REPL

The `Mimic.dll` supports an interactive REPL mode, accepting commands via Standard Input:
*   `LOGIN <First> <Last> <Pass> [URI]`
*   `CHAT <Message>`
*   `REZ` (Creates a primitive object)
*   `SLEEP <seconds>`
*   `WHOAMI`
*   `WHO`
*   `WHERE`
*   `WHEN`
*   `SUBJECTIVE_WHY`
*   `SUBJECTIVE_BECAUSE <text>`
*   `SUBJECTIVE_LOOK`
*   `SUBJECTIVE_GOTO <x>,<y>[,<z>]`
*   `POS <x>,<y>,<z>`
*   `LOGOUT`
*   `EXIT`

### Command Line Arguments

You can run Mimic manually against a running server using the following arguments (which may trigger an auto-login if sufficient credentials are provided):

```bash
# From the repository root
export DOTNET_ROOT=$(./instruments/substrate/ensure_dotnet.sh)
export PATH=$DOTNET_ROOT:$PATH

./vivarium/mimic/Mimic.dll --firstname <First> --lastname <Last> --password <Pass> --uri <LoginURI> --timeout <Seconds>
```

For full CLI documentation, see `observatory/taxonomy/visitant-cli.md`.
