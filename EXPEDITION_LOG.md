# Expedition Log: The Naturalist Observatory

**Status:** ACTIVE MIGRATION (Milestone 2.5)
**Date:** December 2025

## 1. Mission Directive
This repository is transitioning from a standard development project (`OmvTestHarness`) to a **Naturalist Observatory**. Our goal is to capture, catalogue, and observe the "Encounter" between various Metaverse software agents in their natural habitats.

**CRITICAL PROTOCOL:**
* **The Truth:** This log and the `species/` directory represent the current state.
* **The Legacy:** `OmvTestHarness/` is a legacy surrogate site. It is to be mined for genetic material and dismantled. Do not add new features there.
* **The Law:** We operate under a "Safe Harbor" protocol. The `.gitignore` denies everything by default (`/*`), but explicitly whitelists safe zones (`species/`, `instruments/`, `observatory/`, `journals/`). The root directory is Lava; `vivarium/` is a Black Hole.

## 2. The Lexicon (Vibe Check)
We adopt a naturalist taxonomy to describe our work:

* **Species:** The "Wild Type" software we acquire (e.g., OpenSim, Benthic, Firestorm). We do not own it; we observe it.
* **Variant:** A Species adapted to survive in a specific Biome (e.g., Benthic patched for console use).
* **Specimen:** Specific agents (e.g., an instantiated member of a particular Species or of its Variants).
* **Substrate:** Dependencies required for life (e.g., local .NET runtime, Rust).
* **Mimic:** A synthetic agent (formerly "Test Harness") built to facilitate Specimens into Encounters.
* **Instrument:** Tools we build to facilitate observation (e.g., Mimics, Cameras, Loggers).
* **Incubate:** The process of compiling a Specimen from source using the Substrate.
* **Encounter:** The interaction sequence between agents (currently aka: Scenario).
* **Visitant:** The active participant entering a Territory.
* **Range:** The server or grid environment.
* **Territory:** The specific virtual space or Region (eg: a living OpenSim specimen).
* **Field Mark:** A distinctive behavior or code-path observed to identify a species.
* **Sequencer:** A Lab Instrument (CLI tool) that generates SQL (or similar) for injecting into Territory genomes.
* **Teleplay:** A Literate Scenario (`.md`) that acts as a script for the Director. These are "Community Theater" productions where we cast different Species into roles (e.g., "The Host", "The Hero", "The Guest Speaker") to observe their interactions.
* **Conservatory:** The conceptual wing of the project dedicated to "Sheltering" specimens. If a Deep Sea Species cannot easily survive without assistance, we may move it to the Conservatory (create a patched Variant) in order to keep it available by way of life support.
* **Requisite Variety:** The operational necessity for the Observatory to be more flexible than the specimens it contains. If the Deep Sea is high-variance, our Director must be high-nuance.

## 3. The Biomes
We do not use words like "Headless" when describing environments. We engineer Biomes:

* **Deep Sea:** A console-only environment. No display server. Species here may require adaptation (into Variants) to survive without graphical rendering.
* **The Reef:** A simulated graphical environment (Xvfb/Desktop). Species here can be observed in their native UI configuration.

## 4. Architecture
* `species/{genus}/{version}/`: The taxonomy. Contains `acquire.sh`, `adapt_{biome}.sh`, and `instrument.sh`.
* `instruments/`: The Field Kit. Contains the `mimic/` and potential `narrators/`.
* `vivarium/`: Placeholder folder workspace where live specimens are grown and observed (e.g., our themed build/ folder).
* `journals/`: The library of captured Field Notes.

**Containment Rule:** Instruments must act like clean laboratory equipment. They must NEVER dump build artifacts, logs, or binaries into `instruments/` or `species/`. All runtime output goes to `vivarium/`.

## 5. Milestone 3.0: The Director & The Stage
To improve the ergonomics of orchestrating complex Encounters, we have introduced a "Literate Harness" methodology.

*   **The Director:** A Python-based instrument (`instruments/mimic/director.py`) that acts as a stage manager. It parses "Literate Scenarios" to orchestrate the environment.
*   **Literate Scenario:** A Markdown file (e.g., `scenarios/standard.md`) that interweaves narrative description with executable blocks (`bash`, `cast`, `opensim`, `mimic`, `wait`). This replaces the rigid `run_encounter.sh` logic with a composeable script.
*   **Mimic REPL:** The Mimic instrument has been refactored to utilize actual `LibreMetaverse` (rather than opensim "libopenmetaverse") and support an interactive REPL mode, allowing the Director to issue commands (`LOGIN`, `CHAT`, `REZ`) dynamically during an Encounter.
*   **Deep Sea Variants:** We have adapted `OpenSim 0.9.3` for the "Deep Sea" (headless Linux) biome by patching `VectorRenderModule` and `WorldMapModule` to gracefully handle the absence of `libgdiplus` (GDI+), ensuring stability without graphical dependencies. And instrumented `Benthic 0.1.0`'s `metaverse_client` framework into a command line harness without dependence on GUI crates.

---
*End of Log.*
