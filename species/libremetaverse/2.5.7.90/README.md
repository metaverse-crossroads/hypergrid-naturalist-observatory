# LibreMetaverse (Deep Sea Variant)

**Species:** `libremetaverse`
**Version:** `2.5.7.90`
**Substrate:** .NET 8 (Linux/x64)

## Overview
This variant is a headless, cross-platform build of the LibreMetaverse library (v2.5.7), targeted for the .NET 8 runtime. It utilizes the modern upstream source which natively supports .NET 8, removing the need for legacy patches.

## Build Strategy
The incubation process (`incubate.sh`) performs the following mutations:
1.  **Preparation**: Cleans legacy artifacts (e.g. `global.json`) to ensure compatibility with the .NET 8 SDK.
2.  **Pruning**: Removes GUI-dependent projects if present (though 2.5.7 structure is cleaner).
3.  **Synthetic Client**: Generates a transient `DeepSeaClient.csproj` (and project) during build to compile the `DeepSeaClient.cs` source into an executable without polluting the source tree.

## Usage
The primary artifact is `DeepSeaClient`, a console application capable of connecting to OpenSim regions.

```bash
# Run the client
./vivarium/libremetaverse-2.5.7.90/DeepSeaClient_Build/bin/Release/net8.0/DeepSeaClient --help
```

## Known Limitations
*   **No GUI**: Visual components are disabled. This is a text-only interface.
*   **Platform**: Tested strictly on Linux x64 with .NET 8.
