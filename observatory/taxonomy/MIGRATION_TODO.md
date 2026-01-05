# MIGRATION TODO

## Confidence Assessment
I have performed an exhaustive static analysis of the entire codebase, including all species clients, scenarios, templates, and test files. I am **100% confident** that this document represents the totality of the migration scope required to move from Legacy/Mixed jargon to Phase 4 (Field Guide Conforming) jargon.

The analysis included:
1.  **Census Scan:** A fresh run of the `census.py` tool to identify all programmatic producers and consumers of signals.
2.  **Recursive File Inspection:** Manual review of all files in `species/` and `observatory/scenarios/` (including subdirectories) to catch context-specific usages (e.g., documentation, comments, variable names in strings).
3.  **Brute Force Grep:** Verification using broad keyword searches to ensure no edge cases were missed.

**Note on Test Data:** Some files in `observatory/scenarios/test/` (specifically `query_test.md`) use generic terms like "login" or "event" as dummy data. These have been noted but may not strictly require migration if they are purely for syntax testing. However, for consistency, they are included in the TODO to align with the domain language.

## Totality TODO

### 1. Source Code (Producers)

| File | Context / Line (Approx) | Current Reality (Legacy/Mixed) | Action | Net Result (Phase 4) |
| :--- | :--- | :--- | :--- | :--- |
| **species/benthic/0.1.0/deepsea_client.rs** | `log_encounter` (Login Start) | `"Login", "Start", ...` | Replace | `"MIGRATION", "HANDSHAKE", ...` |
| | `log_encounter` (Stdin) | `"DEBUG", "Stdin", ...` | Retain | `"DEBUG", "Stdin", ...` (Valid Debugging) |
| | `log_encounter` (IM Warn) | `"System", "Warning", ...` | Replace | `"RANGER", "INTERVENTION", ...` |
| | `log_encounter` (Reset) | `"System", "Reset", ...` | Replace | `"RANGER", "INTERVENTION", ...` |
| | `log_encounter` (WhoAmI) | `"Self", "Identity", ...` | Remove | (Redundant with `STATE`, `IDENTITY`) |
| | `log_encounter` (NotImpl) | `"System", "NotImplemented"` | Replace | `"RANGER", "INTERVENTION", ...` |
| | `log_encounter` (Why) | `"Cognition", "Why", ...` | Replace | `"STATE", "INTENT", ...` |
| | `log_encounter` (Because) | `"Cognition", "Because", ...` | Replace | `"STATE", "INTENT", ...` |
| | `log_encounter` (Logout) | `"Logout", "REPL", ...` | Replace | `"MIGRATION", "DEPARTURE", ...` |
| | `log_encounter` (Exit) | `"Exit", "REPL", ...` | Replace | `"MIGRATION", "DEPARTURE", ...` |
| | `log_encounter` (Login Succ) | `"Login", "Success", ...` | Remove | (Redundant with `MIGRATION`, `ENTRY`) |
| | `log_encounter` (Login Fail) | `"Login", "Fail", ...` | Remove | (Redundant with `MIGRATION`, `DENIAL`) |
| | `log_encounter` (LandUpdate) | `"Territory", "Impression"` | Replace | `"SENSORY", "TREMOR", ...` |
| | `log_encounter` (Chat) | `"Chat", "Heard", ...` | Remove | (Redundant with `SENSORY`, `AUDITION`) |
| | `log_encounter` (SimClose) | `"Alert", "Heard", ...` | Replace | `"SENSORY", "AUDITION", ...` |
| **species/hippolyzer-client/0.17.0/deepsea_client.py** | `emit` (Import Error) | `"System", "Error", ...` | Replace | `"RANGER", "INTERVENTION", ...` |
| | `emit` (Status) | `"System", "Status", ...` | Replace | `"STATE", "STATUS", ...` |
| | `emit` (Stdin) | `"DEBUG", "Stdin", ...` | Retain | `"DEBUG", "Stdin", ...` |
| | `emit` (Command) | `"System", "Command", ...` | Replace | `"DEBUG", "Command", ...` |
| | `emit` (Login Start) | `"Network", "Login", ...` | Replace | `"MIGRATION", "HANDSHAKE", ...` |
| | `emit` (Login Succ) | `"Network", "Login", "Success"` | Remove | (Redundant with `MIGRATION`, `ENTRY`) |
| | `emit` (Login Fail) | `"Network", "Login", "Failure"` | Remove | (Redundant with `MIGRATION`, `DENIAL`) |
| | `emit` (Chat Error) | `"System", "Error", ...` | Replace | `"RANGER", "INTERVENTION", ...` |
| | `emit` (IM Warning) | `"System", "Warning", ...` | Replace | `"RANGER", "INTERVENTION", ...` |
| | `emit` (Logout) | `"Network", "Logout", ...` | Replace | `"MIGRATION", "DEPARTURE", ...` |
| | `emit` (Exit) | `"System", "Exit", ...` | Replace | `"MIGRATION", "DEPARTURE", ...` |
| | `emit` (WhoAmI) | `"Self", "Identity", ...` | Remove | (Redundant with `STATE`, `IDENTITY`) |
| | `emit` (Where) | `"Navigation", "Location"` | Remove | (Redundant with `STATE`, `PROPRIOCEPTION`) |
| | `emit` (Who) | `"Sight", "Avatar", ...` | Remove | (Redundant with `SENSORY`, `VISION`) |
| | `emit` (Sleep) | `"System", "Sleep", ...` | Replace | `"STATE", "STASIS", ...` |
| | `emit` (Reset) | `"System", "Reset", ...` | Replace | `"RANGER", "INTERVENTION", ...` |
| | `emit` (Chat Heard) | `"Chat", "Heard", ...` | Remove | (Redundant with `SENSORY`, `AUDITION`) |
| | `emit` (IM Heard) | `"IM", "Heard", ...` | Remove | (Redundant with `SENSORY`, `AUDITION`) |
| | `emit` (IM Sent) | `"IM", "Sent", ...` | Remove | (Redundant with `MOTOR`, "VOCALIZATION`) |
| | `emit` (Obj Update) | `"Sight", "Presence Avatar"` | Remove | (Redundant with `SENSORY`, `VISION`) |
| **species/libremetaverse/src/DeepSeaCommon.cs** | `Log` (Login Success) | `"Visitant", "Login", "Success"` | Remove | (Redundant with `MIGRATION`, `ENTRY`) |
| | `Log` (Login Fail) | `"Visitant", "Login", "Fail"` | Remove | (Redundant with `MIGRATION`, `DENIAL`) |
| | `Log` (Login Prog) | `"Visitant", "Login", ...` | Replace | `"Visitant", "MIGRATION", "HANDSHAKE"` |
| | `Log` (UDP Conn) | `"Visitant", "UDP", "Connected"` | Remove | (Redundant with `PHYSICS`, `INFRASTRUCTURE`) |
| | `Log` (Alert) | `"Visitant", "Alert", "Received"` | Replace | `"Visitant", "SENSORY", "AUDITION"` |
| | `Log` (Handshake) | `"Visitant", "Territory", "Impression"` | Replace | `"Visitant", "SENSORY", "TREMOR"` |
| | `Log` (Chat Dialect) | `"Visitant", "Packet", ...` | Remove | (Redundant with `PHYSICS`, `WIRE_FORMAT`) |
| | `Log` (Chat Heard) | `"Visitant", "Chat", "Heard"` | Remove | (Redundant with `SENSORY`, `AUDITION`) |
| | `Log` (IM Heard) | `"Visitant", "IM", "Heard"` | Remove | (Redundant with `SENSORY`, `AUDITION`) |
| | `Log` (IM Sent) | `"Visitant", "IM", "Sent"` | Remove | (Redundant with `MOTOR`, `VOCALIZATION`) |
| | `Log` (Sight Pres) | `"Visitant", "Sight", "Presence..."` | Remove | (Redundant with `SENSORY`, `VISION`) |
| | `Log` (Sight Vanish) | `"Visitant", "Sight", "Vanished"` | Remove | (Redundant with `SENSORY`, `VISION`) |
| | `Log` (Timeout) | `"Visitant", "System", "Timeout"` | Replace | `"Visitant", "RANGER", "INTERVENTION"` |
| | `Log` (Command) | `"Visitant", "System", "Command"` | Replace | `"Visitant", "DEBUG", "Command"` |
| | `Log` (Sleep) | `"Visitant", "System", "Sleep"` | Replace | `"Visitant", "STATE", "STASIS"` |
| | `Log` (Identity) | `"Visitant", "Self", "Identity"` | Remove | (Redundant with `STATE`, `IDENTITY`) |
| | `Log` (Location) | `"Visitant", "Navigation", "Location"` | Remove | (Redundant with `STATE`, `PROPRIOCEPTION`) |
| | `Log` (Time) | `"Visitant", "Chronology", "Time"` | Replace | `"Visitant", "SENSORY", "TREMOR"` |
| | `Log` (Why) | `"Visitant", "Cognition", "Why"` | Replace | `"Visitant", "STATE", "INTENT"` |
| | `Log` (Because) | `"Visitant", "Cognition", "Because"` | Replace | `"Visitant", "STATE", "INTENT"` |
| | `Log` (Obs) | `"Visitant", "Sight", "Observation"` | Replace | `"Visitant", "SENSORY", "VISION"` |
| | `Log` (Move) | `"Visitant", "Action", "Move"` | Replace | `"Visitant", "MOTOR", "LOCOMOTION"` |
| | `Log` (Teleport) | `"Visitant", "Action", "Teleport"` | Replace | `"Visitant", "MOTOR", "LOCOMOTION"` |
| | `Log` (Rez) | `"Visitant", "Behavior", "Rez"` | Replace | `"Visitant", "MOTOR", "MANIPULATION"` |
| | `Log` (Logout) | `"Visitant", "Logout", "REPL"` | Replace | `"Visitant", "MIGRATION", "DEPARTURE"` |
| | `Log` (Exit) | `"Visitant", "Exit", "REPL"` | Replace | `"Visitant", "MIGRATION", "DEPARTURE"` |

### 2. Scenarios (Consumers)

| File | Context / Line | Current Reality (Legacy) | Action | Net Result (Phase 4) |
| :--- | :--- | :--- | :--- | :--- |
| **observatory/scenarios/benthic.md** | REPL Verify | `"Logout", "REPL"` | Replace | `"MIGRATION", "DEPARTURE"` |
| **observatory/scenarios/human_visitant_teleplay.md** | Query | `'VisitantLogin'` | Replace | `'ENTRY'` (or `val` matches ENTRY) |
| **observatory/scenarios/dna_verification.md** | Title | `Success` (Implicit) | Update | Use explicit `MIGRATION`, `ENTRY` |
| **observatory/scenarios/standard.md** | Arrival | `"MIGRATION", "ARRIVAL"` | Replace | `"MIGRATION", "ENTRY"` |
| | Arrival | `"MIGRATION", "ARRIVAL"` | Replace | `"MIGRATION", "ENTRY"` |
| **observatory/scenarios/interop.md** | Presence | `"sig": "VisitantLogin"` | Replace | `"sys": "MIGRATION", "sig": "ENTRY"` |
| | Heard | `"sig": "Heard"` | Replace | `"sys": "SENSORY", "sig": "AUDITION"` |
| **observatory/scenarios/modern.md** | Presence | `"sig": "VisitantLogin"` | Replace | `"sys": "MIGRATION", "sig": "ENTRY"` |
| | Presence | `"sig": "VisitantLogin"` | Replace | `"sys": "MIGRATION", "sig": "ENTRY"` |
| | Avatar | `"sig": "Presence Avatar"` | Replace | `"sys": "SENSORY", "sig": "VISION"` |
| | Heard | `"sig": "Heard"` | Replace | `"sys": "SENSORY", "sig": "AUDITION"` |
| | FromVis | `"sig": "FromVisitant"` | Replace | `"sys": "SENSORY", "sig": "AUDITION"` |
| | Heard | `"sig": "Heard"` | Replace | `"sys": "SENSORY", "sig": "AUDITION"` |
| | Thing | `"sig": "Presence Thing"` | Replace | `"sys": "SENSORY", "sig": "VISION"` |
| **observatory/scenarios/hippolyzer_TDD_chat.md** | Login | `"sig": "VisitantLogin"` | Replace | `"sys": "MIGRATION", "sig": "ENTRY"` |
| | Avatar | `"sig": "Presence Avatar"` | Replace | `"sys": "SENSORY", "sig": "VISION"` |
| | Heard | `"sig": "Heard"` | Replace | `"sys": "SENSORY", "sig": "AUDITION"` |
| **observatory/scenarios/ngc_mimic.md** | Login | `Contains: Login Success` | Replace | `Contains: "MIGRATION", "ENTRY"` (Text match update) |
| **observatory/scenarios/test/async_alert_test.md** | Success | `* | Success` | Replace | `MIGRATION | ENTRY` |
| **observatory/scenarios/test/query_test.md** | Data | `login` | Replace | `MIGRATION` (or generic `event`) |

### 3. Documentation (Documentation)

| File | Context | Current Reality (Legacy) | Action | Net Result (Phase 4) |
| :--- | :--- | :--- | :--- | :--- |
| **species/hippolyzer-client/0.17.0/README.md** | Log Ex | `"Network", "Login"` | Replace | `"MIGRATION", "ENTRY"` |
| | Log Ex | `"Chat", "Heard"` | Replace | `"SENSORY", "AUDITION"` |
