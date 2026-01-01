# LibreMetaverse (Deep Sea Variant)

**Species:** `libremetaverse`
**Version:** `2.0.0.278`
**Substrate:** .NET 8 (Linux/x64)

## Overview
This variant is a headless, cross-platform build of the LibreMetaverse library, targeted for the .NET 8 runtime. It strips away Windows-specific GUI components (WinForms) and legacy dependencies to ensure reliable operation in the Observatory environment (Linux).

## Build Strategy
The incubation process (`incubate.sh`) performs the following mutations:
1.  **Retargeting**: Injects a `Directory.Build.targets` file to force all projects to target `net8.0` (overriding `netstandard2.1` and `net5.0`).
2.  **Pruning**: Removes `LibreMetaverse.GUI` and `Baker` projects from the solution to avoid GDI+ / Windows Forms dependencies.
3.  **Synthetic Client**: Generates a transient `DeepSeaClient.csproj` (and project) during build to compile the `DeepSeaClient.cs` source into an executable without polluting the source tree.

## Usage
The primary artifact is `DeepSeaClient`, a console application capable of connecting to OpenSim regions.

```bash
# Run the client
./vivarium/libremetaverse-2.0.0.278/DeepSeaClient_Build/bin/Release/net8.0/DeepSeaClient --help
```

## Supported Commands
See [Visitant REPL Protocol](../../../observatory/taxonomy/visitant-repl.md).
New commands introduced:
*   `IM <First> <Last> <Message>`: Directory search based instant message.
*   `IM_UUID <UUID> <Message>`: Direct UUID instant message.

## Implementation Notes
*   **Packet Handling**: The `PacketType.InstantMessage` enum member is not available in this version of `LibreMetaverse`. Use `PacketType.ImprovedInstantMessage` for all IM handling to ensure compilation and compatibility with modern OpenSim regions.
*   **Auto-Reply**: The client includes auto-reply logic for "dna" inquiries, which filters out its own messages to prevent feedback loops.

## Known Limitations
*   **No GUI**: Visual components are disabled. This is a text-only interface.
*   **Platform**: Tested strictly on Linux x64 with .NET 8.
