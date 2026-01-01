# DeepSeaCommon

This directory contains the shared core logic for the Visitant REPL used by LibreMetaverse-based clients (Mimic, DeepSeaClient).

## DeepSeaCommon.cs

This C# file implements the `DeepSeaClient` class, which handles:
- Connection to OpenSim grids.
- Visitant REPL command loop (LOGIN, CHAT, WHOAMI, etc.).
- Event handling and logging (EncounterLogger).

## Integration

Consumers should link this file into their project using the `<Link>` attribute in their `.csproj`:

```xml
<ItemGroup>
  <Compile Include="../../src/DeepSeaCommon.cs" Link="DeepSeaCommon.cs" />
</ItemGroup>
```

This ensures a single source of truth for the Visitant behavior across different versions and instruments.
