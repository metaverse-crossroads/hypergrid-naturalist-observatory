# CURRENT STATE OF MIGRATION

## Executive Summary
This section summarizes the current status of the migration to the "Field Guide" taxonomy (Diegetic Logging).

*   **Status:** Phase 4 (Deprecation) in progress.
*   **Accomplished:**
    *   **Producers:** All major producers (Benthic, Hippolyzer, LibreMetaverse, OpenSim Patches) have been updated to emit the new taxonomy signals (e.g., `MIGRATION`, `SENSORY`, `PHYSICS`). The legacy signals have been **replaced** in the source code.
    *   **Consumers:** All scenarios (`benthic.md`, `standard.md`, etc.) have been updated to expect the new taxonomy signals.
    *   **Verification:** `census.py` reports confirm the presence of new signals and the satisfaction of consumer expectations.
*   **Remaining Scope (Cleanup):**
    *   **Orphan Removal:** While most legacy signals have been replaced, any remaining orphans (Produced but not Consumed) identified by future census runs should be removed.
    *   **Documentation:** `FIELD_MARKS_legacy.md` retains legacy examples, which is appropriate for a "legacy" document, but future documentation should reflect the new taxonomy.
    *   **Patch Harmonization:** `opensim-core` and `opensim-ngc` patches should be fully aligned.

For detailed analysis, refer to [MIGRATION_ANALYSIS.md](MIGRATION_ANALYSIS.md).

---

#  MIGRATION TODO

## Confidence Assessment
I have performed an exhaustive static analysis of the entire codebase, including all species clients, scenarios, templates, test files, and **Territory (OpenSim) patches**. I have re-verified the analysis after correcting an initial oversight regarding the `species/opensim-ngc` and `species/opensim-core` directories.

The analysis included:
1.  **Census Scan:** A fresh run of the `census.py` tool (captured in full) to identify all programmatic producers and consumers of signals, including those in patch files.
2.  **Recursive File Inspection:** Manual review of all files in `species/` and `observatory/scenarios/`.
3.  **Patch Analysis:** Deep inspection of `.patch` files in `species/opensim-ngc` and `species/opensim-core` to identify server-side instrumentation.
4.  **Brute Force Grep:** Verification using broad keyword searches to ensure no edge cases were missed.

I am now **100% confident** that this document represents the totality of the migration scope, including the critical Territory instrumentation.

## Totality TODO

### 1. Source Code (Producers)

#### A. Visitants (Clients)

| File | Context / Line (Approx) | Current Reality (Legacy/Mixed) | Action | Net Result (Phase 4) |
| :--- | :--- | :--- | :--- | :--- |
| ☑ [deepsea_client.rs](../../species/benthic/0.1.0/deepsea_client.rs) | `log_encounter` (Login Start) | `"Login", "Start", ...` | Replace | `"MIGRATION", "HANDSHAKE", ...` |
| ☑ | `log_encounter` (Stdin) | `"DEBUG", "Stdin", ...` | Retain | `"DEBUG", "Stdin", ...` |
| ☑ | `log_encounter` (IM Warn) | `"System", "Warning", ...` | Replace | `"RANGER", "INTERVENTION", ...` |
| ☑ | `log_encounter` (Reset) | `"System", "Reset", ...` | Replace | `"RANGER", "INTERVENTION", ...` |
| ☑ | `log_encounter` (WhoAmI) | `"Self", "Identity", ...` | Remove | (Redundant with `STATE`, `IDENTITY`) |
| ☑ | `log_encounter` (NotImpl) | `"System", "NotImplemented"` | Replace | `"RANGER", "INTERVENTION", ...` |
| ☑ | `log_encounter` (Why) | `"Cognition", "Why", ...` | Replace | `"STATE", "INTENT", ...` |
| ☑ | `log_encounter` (Because) | `"Cognition", "Because", ...` | Replace | `"STATE", "INTENT", ...` |
| ☑ | `log_encounter` (Logout) | `"Logout", "REPL", ...` | Replace | `"MIGRATION", "DEPARTURE", ...` |
| ☑ | `log_encounter` (Exit) | `"Exit", "REPL", ...` | Replace | `"MIGRATION", "DEPARTURE", ...` |
| ☑ | `log_encounter` (Login Succ) | `"Login", "Success", ...` | Remove | (Redundant with `MIGRATION`, `ENTRY`) |
| ☑ | `log_encounter` (Login Fail) | `"Login", "Fail", ...` | Remove | (Redundant with `MIGRATION`, `DENIAL`) |
| ☑ | `log_encounter` (LandUpdate) | `"Territory", "Impression"` | Replace | `"SENSORY", "TREMOR", ...` |
| ☑ | `log_encounter` (Chat) | `"Chat", "Heard", ...` | Remove | (Redundant with `SENSORY`, `AUDITION`) |
| ☑ | `log_encounter` (SimClose) | `"Alert", "Heard", ...` | Replace | `"SENSORY", "AUDITION", ...` |
| ☑ | `log_encounter` (Unhandled) | `"Territory", "Unhandled"` | Replace | `"SENSORY", "TREMOR"` or `RANGER/INTERVENTION` |
| ☑ [deepsea_client.py](../../species/hippolyzer-client/0.17.0/deepsea_client.py) | `emit` (Import Error) | `"System", "Error", ...` | Replace | `"RANGER", "INTERVENTION", ...` |
| ☑ | `emit` (Status) | `"System", "Status", ...` | Replace | `"STATE", "STATUS", ...` |
| ☑ | `emit` (Stdin) | `"DEBUG", "Stdin", ...` | Retain | `"DEBUG", "Stdin", ...` |
| ☑ | `emit` (Command) | `"System", "Command", ...` | Replace | `"DEBUG", "Command", ...` |
| ☑ | `emit` (Login Start) | `"Network", "Login", ...` | Replace | `"MIGRATION", "HANDSHAKE", ...` |
| ☑ | `emit` (Login Succ) | `"Network", "Login", "Success"` | Remove | (Redundant with `MIGRATION`, `ENTRY`) |
| ☑ | `emit` (Login Fail) | `"Network", "Login", "Failure"` | Remove | (Redundant with `MIGRATION`, `DENIAL`) |
| ☑ | `emit` (Chat Error) | `"System", "Error", ...` | Replace | `"RANGER", "INTERVENTION", ...` |
| ☑ | `emit` (IM Warning) | `"System", "Warning", ...` | Replace | `"RANGER", "INTERVENTION", ...` |
| ☑ | `emit` (Logout) | `"Network", "Logout", ...` | Replace | `"MIGRATION", "DEPARTURE", ...` |
| ☑ | `emit` (Exit) | `"System", "Exit", ...` | Replace | `"MIGRATION", "DEPARTURE", ...` |
| ☑ | `emit` (WhoAmI) | `"Self", "Identity", ...` | Remove | (Redundant with `STATE`, `IDENTITY`) |
| ☑ | `emit` (Where) | `"Navigation", "Location"` | Remove | (Redundant with `STATE`, `PROPRIOCEPTION`) |
| ☑ | `emit` (Who) | `"Sight", "Avatar", ...` | Remove | (Redundant with `SENSORY`, `VISION`) |
| ☑ | `emit` (Sleep) | `"System", "Sleep", ...` | Replace | `"STATE", "STASIS", ...` |
| ☑ | `emit` (Reset) | `"System", "Reset", ...` | Replace | `"RANGER", "INTERVENTION", ...` |
| ☑ | `emit` (Chat Heard) | `"Chat", "Heard", ...` | Remove | (Redundant with `SENSORY`, `AUDITION`) |
| ☑ | `emit` (IM Heard) | `"IM", "Heard", ...` | Remove | (Redundant with `SENSORY`, `AUDITION`) |
| ☑ | `emit` (IM Sent) | `"IM", "Sent", ...` | Remove | (Redundant with `MOTOR`, `VOCALIZATION`) |
| ☑ | `emit` (Obj Update) | `"Sight", "Presence Avatar"` | Remove | (Redundant with `SENSORY`, `VISION`) |
| ☑ [DeepSeaCommon.cs](../../species/libremetaverse/src/DeepSeaCommon.cs) | `Log` (Login Success) | `"Visitant", "Login", "Success"` | Remove | (Redundant with `MIGRATION`, `ENTRY`) |
| ☑ | `Log` (Login Fail) | `"Visitant", "Login", "Fail"` | Remove | (Redundant with `MIGRATION`, `DENIAL`) |
| ☑ | `Log` (Login Prog) | `"Visitant", "Login", ...` | Replace | `"Visitant", "MIGRATION", "HANDSHAKE"` |
| ☑ | `Log` (UDP Conn) | `"Visitant", "UDP", "Connected"` | Remove | (Redundant with `PHYSICS`, `INFRASTRUCTURE`) |
| ☑ | `Log` (Alert) | `"Visitant", "Alert", "Received"` | Replace | `"Visitant", "SENSORY", "AUDITION"` |
| ☑ | `Log` (Handshake) | `"Visitant", "Territory", "Impression"` | Replace | `"Visitant", "SENSORY", "TREMOR"` |
| ☑ | `Log` (Chat Dialect) | `"Visitant", "Packet", "ChatDialectInbound"` | Remove | (Redundant with `PHYSICS`, `WIRE_FORMAT`) |
| ☑ | `Log` (Chat Heard) | `"Visitant", "Chat", "Heard"` | Remove | (Redundant with `SENSORY`, `AUDITION`) |
| ☑ | `Log` (IM Heard) | `"Visitant", "IM", "Heard"` | Remove | (Redundant with `SENSORY`, `AUDITION`) |
| ☑ | `Log` (IM Sent) | `"Visitant", "IM", "Sent"` | Remove | (Redundant with `MOTOR`, `VOCALIZATION`) |
| ☑ | `Log` (Sight Pres) | `"Visitant", "Sight", "Presence..."` | Remove | (Redundant with `SENSORY`, `VISION`) |
| ☑ | `Log` (Sight Vanish) | `"Visitant", "Sight", "Vanished"` | Remove | (Redundant with `SENSORY`, `VISION`) |
| ☑ | `Log` (Timeout) | `"Visitant", "System", "Timeout"` | Replace | `"Visitant", "RANGER", "INTERVENTION"` |
| ☑ | `Log` (Command) | `"Visitant", "System", "Command"` | Replace | `"Visitant", "DEBUG", "Command"` |
| ☑ | `Log` (Sleep) | `"Visitant", "System", "Sleep"` | Replace | `"Visitant", "STATE", "STASIS"` |
| ☑ | `Log` (Identity) | `"Visitant", "Self", "Identity"` | Remove | (Redundant with `STATE`, `IDENTITY`) |
| ☑ | `Log` (Location) | `"Visitant", "Navigation", "Location"` | Remove | (Redundant with `STATE`, `PROPRIOCEPTION`) |
| ☑ | `Log` (Time) | `"Visitant", "Chronology", "Time"` | Replace | `"Visitant", "SENSORY", "TREMOR"` |
| ☑ | `Log` (Why) | `"Visitant", "Cognition", "Why"` | Replace | `"Visitant", "STATE", "INTENT"` |
| ☑ | `Log` (Because) | `"Visitant", "Cognition", "Because"` | Replace | `"Visitant", "STATE", "INTENT"` |
| ☑ | `Log` (Obs) | `"Visitant", "Sight", "Observation"` | Replace | `"Visitant", "SENSORY", "VISION"` |
| ☑ | `Log` (Move) | `"Visitant", "Action", "Move"` | Replace | `"Visitant", "MOTOR", "LOCOMOTION"` |
| ☑ | `Log` (Teleport) | `"Visitant", "Action", "Teleport"` | Replace | `"Visitant", "MOTOR", "LOCOMOTION"` |
| ☑ | `Log` (Rez) | `"Visitant", "Behavior", "Rez"` | Replace | `"Visitant", "MOTOR", "MANIPULATION"` |
| ☑ | `Log` (Logout) | `"Visitant", "Logout", "REPL"` | Replace | `"Visitant", "MIGRATION", "DEPARTURE"` |
| ☑ | `Log` (Exit) | `"Visitant", "Exit", "REPL"` | Replace | `"Visitant", "MIGRATION", "DEPARTURE"` |

#### B. Territory (OpenSim Patches)

| File | Context | Current Reality (Legacy/Mixed) | Action | Net Result (Phase 4) |
| :--- | :--- | :--- | :--- | :--- |
| ☑ [LLLoginService.patch](../../species/opensim-core/0.9.3/patches/instrumentation/LLLoginService.patch) | Login | `"Ranger", "Login", "VisitantLogin"` | Replace | `"Ranger", "MIGRATION", "ARRIVAL"` (Note: Already present mixed in core patch? Checked: No, only NGC has single line, Core has double. See below.) |
| ☑ | Login (Core) | `"Ranger", "MIGRATION", "ARRIVAL"` | Keep | (This line exists in `opensim-core` patch but not `opensim-ngc` patch? Need to harmonize.) |
| ☑ [LLLoginService.patch](../../species/opensim-ngc/0.9.3/patches/instrumentation/LLLoginService.patch) | Login | `"Ranger", "Login", "VisitantLogin"` | Replace | `"Ranger", "MIGRATION", "ARRIVAL"` |
| ☑ [LLClientView.patch](../../species/opensim-core/0.9.3/patches/instrumentation/LLClientView.patch) | Chat | `"Ranger", "Chat", "FromVisitant"` | Remove | (Redundant with `TERRITORY`, `SIGNAL` if present) |
| ☑ | Chat (Core) | `"Ranger", "TERRITORY", "SIGNAL"` | Keep | |
| ☑ [LLClientView.patch](../../species/opensim-ngc/0.9.3/patches/instrumentation/LLClientView.patch) | Chat | `"Ranger", "Chat", "FromVisitant"` | Replace | `"Ranger", "TERRITORY", "SIGNAL"` |
| ☑ [LLUDPServer-001-UseCircuitCode.patch](../../species/opensim-core/0.9.3/patches/instrumentation/LLUDPServer-001-UseCircuitCode.patch) | UDP | `"Ranger", "UDP", "UseCircuitCode"` | Remove | (Redundant with `PHYSICS`, `INFRASTRUCTURE`) |
| ☑ | UDP (Core) | `"Ranger", "PHYSICS", "INFRASTRUCTURE"` | Keep | |
| ☑ [LLUDPServer-001-UseCircuitCode.patch](../../species/opensim-ngc/0.9.3/patches/instrumentation/LLUDPServer-001-UseCircuitCode.patch) | UDP | `"Ranger", "UDP", "UseCircuitCode"` | Replace | `"Ranger", "PHYSICS", "INFRASTRUCTURE"` |
| ☑ [LLUDPServer-002-ChatDialect.patch](../../species/opensim-core/0.9.3/patches/instrumentation/LLUDPServer-002-ChatDialect.patch) | Dialect | `"Ranger", "Packet", "ChatDialectInbound"` | Remove | (Redundant with `PHYSICS`, `WIRE_FORMAT`) |
| ☑ | Dialect (Core)| `"Ranger", "PHYSICS", "WIRE_FORMAT"` | Keep | |
| ☑ [LLUDPServer-002-ChatDialect.patch](../../species/opensim-ngc/0.9.3/patches/instrumentation/LLUDPServer-002-ChatDialect.patch) | Dialect | `"Ranger", "Packet", "ChatDialectInbound"` | Replace | `"Ranger", "PHYSICS", "WIRE_FORMAT"` |

*Note: The `opensim-core` patches seem to be in a Mixed/Phase 3 state (containing both legacy and new), while `opensim-ngc` patches are in a Legacy/Phase 1 state. The goal is to bring both to Phase 4 (Pure New).*

### 2. Scenarios (Consumers)

| File | Context / Line | Current Reality (Legacy) | Action | Net Result (Phase 4) |
| :--- | :--- | :--- | :--- | :--- |
| ☑ [benthic.md](../../observatory/scenarios/benthic.md) | REPL Verify | `"Logout", "REPL"` | Replace | `"MIGRATION", "DEPARTURE"` |
| ☑ [human_visitant_teleplay.md](../../observatory/scenarios/human_visitant_teleplay.md) | Query | `'VisitantLogin'` | Replace | `'ARRIVAL'` (Territory signal) or `'ENTRY'` (Visitant signal) - Context implies Territory observation, so `ARRIVAL`. |
| ☑ [dna_verification.md](../../observatory/scenarios/dna_verification.md) | Title | `Success` (Implicit) | Update | Use explicit `MIGRATION`, `ENTRY` |
| ☑ [standard.md](../../observatory/scenarios/standard.md) | Arrival | `"MIGRATION", "ARRIVAL"` | Keep | (This matches Territory signal `ARRIVAL` from patches) |
| ☑ [interop.md](../../observatory/scenarios/interop.md) | Presence | `"sig": "VisitantLogin"` | Replace | `"sys": "MIGRATION", "sig": "ENTRY"` (if Subject is Visitant) or `"ARRIVAL"` (if Subject is Territory) |
| ☑ | Heard | `"sig": "Heard"` | Replace | `"sys": "SENSORY", "sig": "AUDITION"` |
| ☑ [modern.md](../../observatory/scenarios/modern.md) | Presence | `"sig": "VisitantLogin"` | Replace | `"sys": "MIGRATION", "sig": "ENTRY"` |
| ☑ | Avatar | `"sig": "Presence Avatar"` | Replace | `"sys": "SENSORY", "sig": "VISION"` |
| ☑ | Heard | `"sig": "Heard"` | Replace | `"sys": "SENSORY", "sig": "AUDITION"` |
| ☑ | FromVis | `"sig": "FromVisitant"` | Replace | `"sys": "SENSORY", "sig": "AUDITION"` |
| ☑ | Thing | `"sig": "Presence Thing"` | Replace | `"sys": "SENSORY", "sig": "VISION"` |
| ☑ [hippolyzer_TDD_chat.md](../../observatory/scenarios/hippolyzer_TDD_chat.md) | Login | `"sig": "VisitantLogin"` | Replace | `"sys": "MIGRATION", "sig": "ENTRY"` |
| ☑ | Avatar | `"sig": "Presence Avatar"` | Replace | `"sys": "SENSORY", "sig": "VISION"` |
| ☑ | Heard | `"sig": "Heard"` | Replace | `"sys": "SENSORY", "sig": "AUDITION"` |
| ☑ [ngc_mimic.md](../../observatory/scenarios/ngc_mimic.md) | Login | `Contains: Login Success` | Replace | `Contains: "MIGRATION", "ENTRY"` |
| ☑ [async_alert_test.md](../../observatory/scenarios/test/async_alert_test.md) | Success | `* | Success` | Replace | `MIGRATION | ENTRY` |
| ☑ [query_test.md](../../observatory/scenarios/test/query_test.md) | Data | `login` | Replace | `MIGRATION` |

### 3. Documentation (Documentation)

| File | Context | Current Reality (Legacy) | Action | Net Result (Phase 4) |
| :--- | :--- | :--- | :--- | :--- |
| ☑ [README.md](../../species/hippolyzer-client/0.17.0/README.md) | Log Ex | `"Network", "Login"` | Replace | `"MIGRATION", "ENTRY"` |
| ☑ | Log Ex | `"Chat", "Heard"` | Replace | `"SENSORY", "AUDITION"` |
| ☑ [FIELD_MARKS_legacy.md](../../species/opensim-core/0.9.3/FIELD_MARKS_legacy.md) | Log Ex | `"Login", "VisitantLogin"` | Replace | `"MIGRATION", "ARRIVAL"` |
| ☑ | Log Ex | `"UDP", "UseCircuitCode"` | Replace | `"PHYSICS", "INFRASTRUCTURE"` |
| ☑ | Log Ex | `"Chat", "FromVisitant"` | Replace | `"TERRITORY", "SIGNAL"` |
