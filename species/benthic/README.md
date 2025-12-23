# Species: Benthic

**Classification:** Client Application / Viewer
**Role:** The Visitant

This directory contains the DNA required to reconstruct a Benthic Metaverse Client.

## Subspecies
* **0.1.0**: The experimental Rust-based client (Deep Sea Variant).

## Artifacts
* `acquire.sh`: Clones the required repositories (Client, Mesh, Serde).
* `incubate.sh`: Compiles the Specimen. It dynamically grafts the `headless_client` into the upstream workspace.
* `headless_client.rs`: The source code for the Deep Sea (Headless) Visitant.
* `run_visitant.sh`: A wrapper script to launch the Visitant with familiar arguments.
