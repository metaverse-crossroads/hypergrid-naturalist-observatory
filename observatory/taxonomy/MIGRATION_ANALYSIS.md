# MIGRATION ANALYSIS: FIELD GUIDE ADOPTION
**Date:** 2025-05-20
**Subject:** Transition to Diegetic Logging (Field Guide)
**Status:** COMPLETED

## 1. Executive Summary
This analysis assesses the feasibility, scope, and impact of adopting the `field-guide.md` logging conventions across the Naturalist Observatory. The goal is to transition from implementation-specific logging (e.g., `sys: UDP`) to "Diegetic" logging (e.g., `sys: TERRITORY`) that follows the biological metaphor.

**Recommendation:** Proceed with a **Clean Room / Dual-Stack Strategy**.
*   **Feasibility:** High. The code paths are well-isolated in patches and client source files.
*   **Risk:** Medium. Breaking scenarios is the primary risk. The dual-stack approach mitigates this by allowing Scenarios to be migrated incrementally.
*   **Effort:** Medium. Requires updating ~8 patches, 3 client codebases, and ~12 scenarios.

---

## 2. Methodology: Dual-Stack Strategy
To ensure zero downtime for verification, we will implement a transition period where instruments emit **BOTH** the Legacy and the New signals.

### Phase 1: Instrumentation (Dual Emission) - COMPLETED
We modified the `EncounterLogger` (C#), `log_encounter` (Rust), and `emit` (Python) to support a secondary emission path or simply emit two log lines per event.

**Example (Benthic):**
```rust
// Old
log_encounter("Chat", "Heard", "Hello");

// New (Added)
log_encounter("SENSORY", "AUDITION", "Hello");
```

**Example (Hippolyzer):**
```python
# Old
emit("Chat", "Heard", message)

# New (Added)
emit("SENSORY", "AUDITION", message)
```

### Phase 2: Verification - COMPLETED
We ran the `census.py` tool to confirm that the new signals (`sys: SENSORY`) are appearing in the logs alongside the orphans (`sys: Chat`).

### Phase 3: Consumer Adoption - COMPLETED
We updated `observatory/scenarios/*.md` file by file.
*   *Before:* `Contains: "sig": "Heard"` (often missing `sys`)
*   *After:* `Contains: "sys": "SENSORY", "sig": "AUDITION"`

### Phase 4: Deprecation - PENDING
Once `census.py` reports that Legacy signals are "Orphans" (Produced but not Consumed), we will remove the legacy logging calls from the patches/clients.

---

## 3. Signal Mapping Table

The following table defines the translation from Legacy patterns to the Field Guide Taxonomy.

| LEGACY SYS | LEGACY SIG | NEW SYS | NEW SIG | NOTES |
| :--- | :--- | :--- | :--- | :--- |
| **Login** | `VisitantLogin` | **MIGRATION** | `ARRIVAL` | Server side acceptance. |
| **Login** | `Success` | **MIGRATION** | `ENTRY` | Client side success. |
| **Login** | `Fail` | **MIGRATION** | `DENIAL` | |
| **Chat** | `Heard` | **SENSORY** | `AUDITION` | The act of hearing. |
| **Chat** | `FromVisitant` | **TERRITORY** | `SIGNAL` | Server relaying input (Subject: Territory). |
| **IM** | `Heard` | **SENSORY** | `AUDITION` | |
| **IM** | `Sent` | **MOTOR** | `VOCALIZATION` | *Verify usage matches Intent.* |
| **Sight** | `Avatar/Thing` | **SENSORY** | `VISION` | |
| **Sight** | `Vanished` | **SENSORY** | `VISION` | Payload: "Vanished ID" |
| **UDP** | `UseCircuitCode` | **PHYSICS** | `INFRASTRUCTURE` | |
| **Packet** | `ChatDialectInbound` | **PHYSICS** | `WIRE_FORMAT` | |
| **Navigation** | `Location` | **STATE** | `PROPRIOCEPTION` | Knowing one's own position. |
| **Self** | `Identity` | **STATE** | `IDENTITY` | |

---

## 4. Impact Analysis (Surface Area)

### A. Producers (Instrumentation)
The following files require modification to inject the new signals.

**OpenSim (Territory)**
*   `species/opensim-core/0.9.3/patches/instrumentation/LLLoginService.patch`
*   `species/opensim-core/0.9.3/patches/instrumentation/LLClientView.patch`
*   `species/opensim-core/0.9.3/patches/instrumentation/LLUDPServer-001-UseCircuitCode.patch`
*   `species/opensim-core/0.9.3/patches/instrumentation/LLUDPServer-002-ChatDialect.patch`
*   *(Same for `opensim-ngc`)*

**Visitants**
*   `species/libremetaverse/src/DeepSeaCommon.cs` (Shared by Mimic)
*   `species/benthic/0.1.0/deepsea_client.rs`
*   `species/hippolyzer-client/0.17.0/deepsea_client.py`

### B. Consumers (Scenarios)
The `census.py` tool identified 54 consumer points. Most use "Wildcard" matching (checking `sig` without `sys`).
*   `observatory/scenarios/standard.md` (Multiple checks for `Heard`, `VisitantLogin`, `FromVisitant`)
*   `observatory/scenarios/benthic.md`
*   `observatory/scenarios/modern.md`
*   `observatory/scenarios/hippolyzer_TDD_chat.md`
*   `observatory/scenarios/interop.md`

### C. Logical Inversions (Bad Teleplays)
The census detected potential logical flaws where scenarios verify `MOTOR` (Intent) instead of `SENSORY` (Effect).
*   *Heuristic:* Scenarios awaiting `IM: Sent` or similar "Output" signals on the Visitant itself.
*   *Action:* These must be rewritten to check the *recipient's* log.

### D. Dynamic Strings
Note that `census.py` cannot resolve dynamic C# strings like `$"Presence {type}"`.
*   Result: `Sight: Avatar` appears as an Orphan, and `Presence Avatar` appears as a Hallucination.
*   Mitigation: Manual verification is required for these dynamic signals during Phase 2.

---

## 5. Next Steps
1.  **Approve** this analysis.
2.  **Authorize** Phase 1 (Instrumentation) updates on `opensim-core` and `mimic`.
3.  **Run** `census.py` to confirm dual emission.
4.  **Completed** Phase 3 (Consumer Adoption).
5.  **Proceed** to Phase 4 (Deprecation) when appropriate.
