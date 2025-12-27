# Emergency Salvage Protocol: LibreMetaverse Species (WIP)

**Status:** HALTED / INCOMPLETE
**Version:** 2.0.0.278
**Date:** Current Session

## 1. Context (Standalone)
We are bootstrapping a new species `libremetaverse` (version 2.0.0.278) to replace/augment the legacy `instruments/mimic`.
The goal is to build `LibreMetaverse` from source (github tag `2.0.0.278`) and a prototype `DeepSeaClient.cs` (cloned from Mimic) on a Linux/dotnet 8 substrate.

## 2. Current State
*   **Directory:** `species/libremetaverse/2.0.0.278/`
*   **Acquire:** `acquire.sh` is set to clone `https://github.com/cinderblocks/libremetaverse.git` at commit `2.0.0.278`.
*   **Incubate:** `incubate.sh` contains logic to:
    1.  Remove Windows-only projects (`GUI`, `Baker`).
    2.  Sed-replace `net5.0`/`netcoreapp3.1` to `net8.0`.
    3.  Build the solution.
    4.  Build `DeepSeaClient.csproj`.
*   **DeepSeaClient:** Located in `src/`. It is a copy of `Mimic.cs`.

## 3. The Failure (Why we halted)
We entered a loop of "trial and error" trying to compile `DeepSeaClient`.
*   **The specific error:** The `dotnet build` command for `DeepSeaClient` was failing or incorrectly pathing its output.
*   **The "Obj Decoy" Trap:** We placed a file named `obj` in `src/` to prevent auto-staging. However, `dotnet build` often fails if it detects this file, even if `BaseIntermediateOutputPath` is redirected. The build was failing with "The file .../obj already exists".

## 4. Missteps to Avoid (Do NOT Repeat)
*   **Do NOT build `HEAD`:** The master branch requires .NET 9. Stick to `2.0.0.278`.
*   **Do NOT patch Source Generators:** We wasted time trying to patch `PacketSourceGenerator` references. The standard build (after retargeting to .NET 8) works fine without this.
*   **Do NOT brute force paths:** Use `dotnet build -c Release` on the solution first.
*   **Handle the "Obj Decoy" properly:** If using the decoy file strategy (a file named `obj`), you **MUST** ensure `dotnet` is absolutely forbidden from trying to use that path. If `dotnet build` complains about the file existing, either move the decoy creation *after* the build (risky for git hygiene) or ensure the `csproj` fully overrides path defaults.

## 5. Tasks for Next Session
1.  **Fix `incubate.sh`:**
    *   Ensure `DeepSeaClient` builds successfully.
    *   Resolve the `obj` file conflict (maybe use a directory `obj/` with a `.gitignore` inside instead of a file, or perfect the output path redirection).
2.  **Verify Execution:**
    *   Ensure `run_visitant.sh` launches the DLL.
3.  **Documentation (Pending):**
    *   Refactor `EXPEDITION_LOG.md`:
        *   Remove legacy terms ("Mating Ritual", "OmvTestHarness").
        *   Group Lexicon items (Taxonomy, Environment, Tools).
4.  **Final Polish:**
    *   Ensure `AGENTS.md` protocols are met without breaking the build.
