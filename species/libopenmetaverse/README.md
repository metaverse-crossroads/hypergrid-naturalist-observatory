# LibOpenMetaverse Findings Report

## Overview

This report documents the specific versions and sources of the `OpenMetaverse` libraries used by the OpenSim variants in this observatory. The investigation reveals a split lineage where "Core" relies on ancient vendorized binaries, while "NGC" utilizes a maintained fork adapted for modern .NET runtimes.

## 1. OpenSim Core (0.9.3)

*   **Variant:** `species/opensim-core/0.9.3`
*   **Source Type:** Vendorized Legacy Binaries
*   **Location:** `bin/OpenMetaverse.dll` (committed directly to the repo)
*   **Upstream Source:** `https://github.com/opensim/libopenmetaverse`
*   **Version Identification:**
    *   **AssemblyVersion:** `0.9.4.0`
    *   **Runtime:** .NET Framework 4.x (`4.0.30319`)
    *   **MD5 Checksum:** `36a271baa07790fa36a0c033ed9a32a4`
*   **Logic Signature:** Contains `FloatZeroOneToushort` implementation identical to the upstream legacy repo.
*   **Analysis:** This dependency is effectively frozen in time. The `opensim/libopenmetaverse` repository is the canonical source for this "0.9.x" era code, which differs significantly in API and namespace structure from the modern "LibreMetaverse" (2.x).

## 2. OpenSim NGC (Tranquillity)

*   **Variant:** `species/opensim-ngc`
*   **Source Type:** Modernized Fork (Source Build)
*   **Location:** `Library/` (mapped to `bin/` in project files)
*   **Upstream Source:** `https://github.com/OpenSim-NGC/libopenmetaverse`
*   **Branch:** `develop` (contains the modernization changes)
*   **Version Identification:**
    *   **AssemblyVersion:** `0.9.4.0` (Maintains legacy versioning for compatibility)
    *   **Runtime:** .NET 8.0 / Standard 2.1
    *   **MD5 Checksum:** `a4864876bb96a37a49ac1f3cbc929c22` (Distinct from Core)
*   **Key Differences:**
    *   **Project Files:** Updated to include `<TargetFrameworks>net48;netstandard2.0;netstandard2.1</TargetFrameworks>`.
    *   **Dependencies:** Upgraded `System.Drawing.Common` to `6.0.0` and `log4net` to `2.0.14`.
    *   **Code:** Merges upstream changes from `opensim/libopenmetaverse` (e.g., commit `c1eec23` merging `upstream/master`).
*   **Analysis:** OpenSim-NGC has performed a "soft fork" of the library. Instead of migrating to LibreMetaverse 2.x (which would require massive refactoring of OpenSim itself), they have ported the legacy 0.9.x codebase to .NET Standard/8. This allows them to run natively on modern runtimes while keeping the old API surface.

## 3. Reference Summary

| Feature | OpenSim Core | OpenSim NGC | Official LibreMetaverse |
| :--- | :--- | :--- | :--- |
| **Namespace** | `OpenMetaverse` | `OpenMetaverse` | `OpenMetaverse` |
| **Code Era** | Legacy (0.9.x) | Legacy (0.9.x) | Modern (2.x) |
| **Runtime** | .NET Framework 4.8 | .NET 8 / Standard 2.1 | .NET 8 / Standard 2.0 |
| **Repo** | `opensim/libopenmetaverse` | `OpenSim-NGC/libopenmetaverse` | `LibreMetaverse/LibreMetaverse` |
| **Strategy** | Vendorized Binaries | Custom Fork/Build | NuGet / Submodule |

## Conclusion

Any attempt to unify these dependencies must account for the API split.
*   **Path A (Conservation):** To build OpenSim NGC (or a derivative), one **must** use the `OpenSim-NGC/libopenmetaverse` fork. The official LibreMetaverse 2.x is **not** a drop-in replacement due to API divergence.
*   **Path B (Evolution):** Migrating OpenSim to LibreMetaverse 2.x would be a significant undertaking, likely requiring changes to thousands of lines of code in the core simulator.

## Appendix: Modernization Theory (LibreMetaverse 2.x)

Replacing the internal engine of OpenSim NGC with LibreMetaverse 2.x (e.g., 2.5.7.90) is theoretically possible but difficult:

1.  **API Divergence:** The 2.x branch has cleaned up and refactored many APIs present in 0.9.x.
2.  **Shim Layer:** A "Shim" or "Adapter" library might be needed to map old `OpenMetaverse` calls to the new 2.x API to avoid rewriting OpenSim.
3.  **Namespace Collision:** Both libraries use `OpenMetaverse`. Running them side-by-side is impossible without extern aliases.
