# Species: Benthic

**Classification:** Client Application / Viewer
**Role:** The Visitant

This directory contains the DNA required to reconstruct a Benthic Metaverse Client.

## Subspecies
* **0.1.0**: The experimental Rust-based client (Deep Sea Variant).

## Artifacts
* `acquire.sh`: Clones the required repositories (Client, Mesh, Serde).
* `incubate.sh`: Compiles the Specimen. It dynamically grafts the `deepsea_client` (formerly `headless_client`) into the upstream workspace.
* `deepsea_client.rs`: The source code for the Deep Sea (Headless) Visitant. Renamed from `headless_client.rs` to align with the Naturalist lexicon.
* `run_visitant.sh`: A wrapper script to launch the Visitant with familiar arguments.

## Journal

### Deep Sea Variant Integration
The `headless_client` was renamed to `deepsea_client` to better reflect its role in the Deep Sea expeditions and adhere to the project's lexicon. The incubation process was updated to graft `deepsea_client` instead of `headless_client`.

### Logging and Instrumentation
- **User Agent (UA) Tagging**: Benthic now includes a `ua` field in its JSON logs (e.g., `"ua": "benthic/0.1.0"`) to aid in identifying the source of logs during interop scenarios.
- **Signal Handling**: The client uses a simple timeout loop but now logs `Logout` signals more reliably.
- **Chat**: Benthic listens for `ChatFromSimulator` packets and logs them as `Chat` system events. Note that this requires the upstream `metaverse_core` to forward these packets as `UIMessage`s.
- **LandUpdate Spam**: Logic was added to suppress repetitive `LandUpdate` logs, only logging the first occurrence to keep the signal-to-noise ratio high.
