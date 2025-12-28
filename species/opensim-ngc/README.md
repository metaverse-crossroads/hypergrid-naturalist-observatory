# Species: OpenSim NGC

**Classification:** Server Application / Grid
**Role:** The Range (Variant)

This species represents the `OpenSim-NGC/OpenSim-Tranquillity` fork, which aims for modern .NET compatibility and other improvements.

## Subspecies
* **0.9.3**: Based on `tranquillity-0.9.3.9441`.

## Artifacts
* `acquire.sh`: Clones the required repositories.
* `incubate.sh`: Compiles the Specimen using `dotnet build` (skipping Prebuild). It also copies runtime assets from `bin/` to `build/Release/`.
* `standalone-observatory-sandbox.ini`: Configuration for a standalone sandbox environment.

## Patches
* `LocalConsoleRedirect.patch`: Applied to enable `director.py` automation.
* `EncounterLogger.patch` and others: Instrumentation applied.
* **Note**: `VectorRenderModule` and `WorldMapModule` patches were removed as NGC uses SkiaSharp instead of GDI+.

## Usage
To run a manual instance after incubation:

```bash
cd vivarium/opensim-ngc-0.9.3/build/Release
dotnet OpenSim.dll -inifile=../../../../species/opensim-ngc/standalone-observatory-sandbox.ini -inidirectory=.
```

**Note**: The `-inidirectory=.` argument is crucial as the sandbox INI uses `${Startup|inidirectory}` to locate databases and logs.
