# LibreMetaverse 2.5.7.90 Integration Theory

## Overview

This document outlines the findings and proposed strategy for integrating the modern, official **LibreMetaverse 2.5.7.90** into the observatory. Unlike the legacy `libopenmetaverse` (0.9.x) used by OpenSim, this version represents the active evolution of the library, featuring modern .NET support, performance improvements, and API changes.

## Current State Analysis

*   **Target Version:** `2.5.7.90` (Latest stable on NuGet as of investigation).
*   **Source:** `https://github.com/cinderblocks/libremetaverse` (Canonical modern repo).
*   **Runtime Support:** Explicitly supports .NET 8.0.
*   **Prior Art:** The observatory currently contains `species/libremetaverse/2.0.0.278`, which appears to be an earlier attempt or snapshot of this modern lineage.

## Integration Theory

Integrating this version serves two potential purposes:
1.  **Visitant Development:** As a client library for building modern bots/tools (like the `Benthic` project or `Mimic`). It is perfectly successfully suited for this.
2.  **Simulator Dependency:** Replacing the legacy `OpenMetaverse.dll` in OpenSim. **This is High Risk.**

### Strategy for Visitant/Tool Integration

For tools separate from the OpenSim core (e.g., a standalone bot):
1.  **Acquisition:** Clone the official repo or consume via NuGet.
    *   *Note:* The "Cosmic Naturalist Imperative" prefers source compilation to ensure containment and reproducibility.
2.  **Incubation:**
    *   Use `dotnet build` targeting .NET 8.
    *   Ensure all dependencies (e.g., `System.Drawing.Common`, `log4net`) are strictly version-locked to avoid "DLL Hell" if running alongside OpenSim assemblies.

### Strategy for Simulator Integration (Theoretical)

Replacing the internal engine of OpenSim NGC with LibreMetaverse 2.x is theoretically possible but difficult:
1.  **API Divergence:** The 2.x branch has cleaned up and refactored many APIs present in 0.9.x.
2.  **Shim Layer:** A "Shim" or "Adapter" library might be needed to map old `OpenMetaverse` calls to the new 2.x API to avoid rewriting OpenSim.
3.  **Namespace Collision:** Both libraries use `OpenMetaverse`. Running them side-by-side is impossible without extern aliases.

## Future Work (TODO)

To advance this species, the following steps are required in a future session:

*   [ ] **Validation:** Verify if `2.5.7.90` compiles cleanly on the observatory's Linux/.NET 8 substrate without modification.
*   [ ] **Comparison:** Diff the public API of `2.5.7.90` against the NGC `0.9.4.0` fork to quantify the "breaking changes."
*   [ ] **Prototype:** Update `species/libremetaverse/2.0.0.278` (or create a new `2.5.7.90` variant) to build the `TestClient` example and verify connectivity to a local `opensim-ngc` instance.
*   [ ] **Documentation:** Update the main `species/libremetaverse/README.md` to distinguish between "Legacy Support" (NGC fork) and "Modern Client" (Official LibreMetaverse).

## Artifacts

*   **NuGet:** `LibreMetaverse`
*   **Source:** `https://github.com/cinderblocks/libremetaverse`
