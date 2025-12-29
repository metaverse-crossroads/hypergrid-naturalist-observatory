# Benthic Specimen

**Benthic** is a Rust-based Metaverse Client specimen. It is an adaptation of the `metaverse_client` crate, instrumented for the Naturalist Observatory.

## Overview

Benthic is designed to function as a "Deep Sea" (headless) visitant. It shares a unified CLI and REPL interface with the **Mimic** instrument, allowing for interchangeable use in automated scenarios.

## Build Instructions

To incubate (build) the Benthic specimen:

```bash
make benthic
```

This will:
1.  Acquire the source code into `vivarium/benthic-<version>`.
2.  Apply necessary patches.
3.  Compile the `deepsea_client` binary using Cargo.

## Usage

### Benthic REPL

Benthic supports an interactive REPL mode, accepting commands via Standard Input:
*   `LOGIN <First> <Last> <Pass> [URI]` (Currently auto-login via CLI args is also supported)
*   `CHAT <Message>`
*   `SLEEP <seconds>`
*   `WHOAMI`
*   `WHO` (Not yet implemented)
*   `WHERE` (Not yet implemented)
*   `WHEN` (Not yet implemented)
*   `SUBJECTIVE_WHY`
*   `SUBJECTIVE_BECAUSE <text>`
*   `SUBJECTIVE_LOOK` (Not yet implemented)
*   `SUBJECTIVE_GOTO <x>,<y>[,<z>]` (Not yet implemented)
*   `POS <x>,<y>,<z>` (Not yet implemented)
*   `LOGOUT`
*   `EXIT`

### Command Line Arguments

```bash
./vivarium/benthic-0.1.0/target/release/deepsea_client --firstname <First> --lastname <Last> --password <Pass> --uri <LoginURI> --timeout <Seconds>
```

For full CLI documentation, see `observatory/taxonomy/visitant-cli.md`.

## TODO: Parity Gaps

The following Visitant capabilities are currently stubbed in Benthic and need implementation to reach parity with Mimic:

*   **WHO**: Listing nearby avatars.
*   **WHERE**: Reporting current location.
*   **WHEN**: Reporting grid time.
*   **SUBJECTIVE_LOOK**: Inspecting the environment.
*   **SUBJECTIVE_GOTO**: Movement/Autopilot.
*   **POS**: Teleportation.
