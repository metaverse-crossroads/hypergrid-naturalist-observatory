# Work-in-Progress: WebRTC Interop Encounter

## 1. Summary
This session sought to prototype a WebRTC Voice teleplay scenario involving LibreMetaverse 2.5.7 and OpenSim 0.9.3. Key achievements included:
- **Refactoring `DeepSeaCommon.cs`**: `DeepSeaClient` was refactored to be non-static and extended with a virtual `HandleCustomCommand` to easily expose new variants to the REPL.
- **LibreMetaverse Voice Client Implementation**: A new `DeepSeaClientWithVoice` class was authored for `species/libremetaverse/2.5.7.90/src/DeepSeaClient.cs`. It handles `VOICE_CONNECT`, `VOICE_PLAY`, and `VOICE_STOP` commands via `LibreMetaverse.Voice.WebRTC.VoiceManager`, emitting NDJSON telemetry using an injected `EncounterLogger`.
- **OpenSim Core Telemetry Injection**: The OpenSim `WebRTCSIPSorcery` mock plugin (`species/opensim-core/plugins/WebRTCSIPSorcery.cs`) was successfully extended to output NDJSON field markers corresponding to `PROVISION_CAP`, `PROVISION_REQUEST`, and `SDP_COMPLETE`.
- **Director & Scenario Orchestration**: Authored `observatory/scenarios/webrtc.md` to cast two `libremetaverse-2.5.7.90` Visitants into an OpenSim territory. Addressed a routing bug in the Stagehand Director to properly launch version-specific binaries.

**High-Level Blocker:**
The scenario successfully completed the HTTP/Region startup and spawned the Visitants into OpenSim. The Visitants connected and correctly fired the initial WebRTC signaling. However, `LibreMetaverse.Voice.WebRTC` hard-depends on an audio sink via SDL3. On the `linux-x64` test architecture, the upstream NuGet package `SIPSorceryMedia.SDL3.Native` (v3.2.28) completely lacks a native `libSDL3.so` binary, causing the client to crash with `Unable to load shared library 'SDL3' or one of its dependencies` upon initializing the Voice subsystem.

---

## 2. SDL3 SPIKE PROMPT
**Purpose:** Resolve a missing native library dependency (`libSDL3.so`) preventing LibreMetaverse's WebRTC Voice implementation from running in headless Linux (Observatory) environments.

**Context:**
The Observatory is a containerized sandbox used for testing virtual world interop. The system operates on Linux (`linux-x64`), using a standard .NET 8.0 SDK. We are attempting to utilize `LibreMetaverse.Voice.WebRTC`, which relies on `SIPSorceryMedia.SDL3.Native` for audio I/O. Currently, calling into this subsystem fails with:
`Unable to load shared library 'SDL3' or one of its dependencies.`
An investigation revealed that the `SIPSorceryMedia.SDL3.Native` NuGet package does not distribute a Linux binary.

**Your Mission:**
1. **Isolate:** Create a minimal, standalone `.cs` and `.csproj` test harness in a temporary directory (e.g., `tests/sdl3-spike`). This harness should reference `SIPSorceryMedia.SDL3` (and any related dependencies) and attempt to initialize a basic SDL3 audio session or query the SDL3 version.
2. **Build & Execute:** Verify that running `dotnet run` on this harness reproduces the `Unable to load shared library 'SDL3'` exception.
3. **Resolve:** Devise a headless, CI-friendly workaround. This might involve:
    - Compiling SDL3 from source and placing `libSDL3.so` in the correct output directory alongside the built binary.
    - Installing a system-level SDL3 package (if available on the host OS).
    - Finding an alternative NuGet package or fork that correctly distributes Linux binaries.
4. **Document:** Ensure your solution is repeatable (e.g., via a bash script or `.csproj` `<Target>` that runs prior to compilation). Provide instructions on how to incorporate this fix into the broader `LibreMetaverse.Voice.WebRTC` build pipeline.

---

## 3. COMPLETION PROMPT
**Purpose:** Finalize the integration of the WebRTC teleplay scenario between LibreMetaverse and OpenSim now that the underlying SDL3 dependency has been resolved.

**Context:**
In a prior session, we developed a work-in-progress branch that implements a WebRTC Voice encounter. We have refactored `DeepSeaClient` to support `VOICE_CONNECT` and `VOICE_PLAY` commands, injected NDJSON telemetry into OpenSim's `WebRTCSIPSorcery` plugin, and authored a teleplay scenario `webrtc.md` to choreograph two `libremetaverse-2.5.7.90` Visitants. This work was stalled by an `SDL3.so` native library loading issue on Linux, which has now been fixed and merged into the current branch.

**Your Mission:**
1. **Assess the Environment:** Review the current state of `observatory/scenarios/webrtc.md`, `species/libremetaverse/2.5.7.90/src/DeepSeaClient.cs`, and `species/opensim-core/plugins/WebRTCSIPSorcery.cs`.
2. **Verify Telemetry & Signaling:** Use the Stagehand director (`python3 observatory/stagehand.py run observatory/scenarios/webrtc.md`) to run the scenario.
3. **Stabilize:** Ensure that the sequence successfully completes: the region starts, both Visitants log in, they request voice connectivity, OpenSim responds with provisional capabilities (`PROVISION_CAP`), and the WebRTC SDP negotiation finishes (`SDP_COMPLETE`).
4. **Final Polish:** If the scenario fails due to timing, adjust the `WAIT` durations or `Timeout` values in the `webrtc.md` file. Ensure the test output reflects a passing `OBSERVATION` report.
5. **Submit:** Once the execution is stable and completely green, run the standard pre-commit instructions and submit the PR.