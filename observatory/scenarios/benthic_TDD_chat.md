---
Title: Benthic Chat TDD Verification
ID: benthic_tdd_chat
---

# Benthic Chat TDD Verification

This scenario establishes a controlled environment to verify chat capabilities (Mouth/Ears) of the Benthic Visitant by comparing it against a known working control group (Mimic).

## 1. Environment Setup
Prepare the habitat.

[#include](templates/prepare_habitat.md)

## 2. Territory Initialization
Initialize OpenSim.

[#include](templates/territory.opensim-core-0.9.3.initialize-simulation.md)

## 3. The Cast
We invite four visitants:
1. **Mimic One** (Control Speaker)
2. **Mimic Two** (Control Listener)
3. **Benthic One** (Test Speaker)
4. **Benthic Two** (Test Listener)

```cast
[
    {
        "First": "Mimic",
        "Last": "One",
        "Password": "password",
        "UUID": "11111111-1111-1111-1111-111111111111"
    },
    {
        "First": "Mimic",
        "Last": "Two",
        "Password": "password",
        "UUID": "22222222-2222-2222-2222-222222222222"
    },
    {
        "First": "Benthic",
        "Last": "One",
        "Password": "password",
        "UUID": "33333333-3333-3333-3333-333333333333",
        "Species": "Benthic"
    },
    {
        "First": "Benthic",
        "Last": "Two",
        "Password": "password",
        "UUID": "44444444-4444-4444-4444-444444444444",
        "Species": "Benthic"
    }
]
```

## 4. The Encounter

### Territory Live
Start the simulation.

```opensim
# Start Live
```
[#include](templates/territory.opensim-core-0.9.3.await-region.md)
[#include](templates/territory.opensim-core-0.9.3.await-login-service.md)

### Stage 1: Arrival
All visitants enter the territory.

```mimic Mimic One
LOGIN Mimic One password
```

```wait
2000
```

```mimic Mimic Two
LOGIN Mimic Two password
```

```wait
2000
```

```mimic Benthic One
LOGIN Benthic One password
```

```wait
2000
```

```mimic Benthic Two
LOGIN Benthic Two password
```

```await
Title: All Visitants Present (Territory)
Subject: Territory
Contains: "val": "Mimic One"
Contains: "val": "Mimic Two"
Contains: "val": "Benthic One"
Contains: "val": "Benthic Two"
```

### Stage 2: Control Experiment (Mimic Speaks)
Mimic One speaks. We expect everyone with working ears to hear it.

```mimic Mimic One
CHAT Mimic Control Test
```

```await
Title: Control Stimulus (Territory Received)
Subject: Territory
Contains: "sig": "FromVisitant"
Contains: "val": "Mimic Control Test"
Timeout: 10000
```

```await
Title: Control Observation (Mimic Listener)
Subject: Mimic Two
Contains: "sig": "Heard"
Contains: "val": "From: Mimic One, Msg: Mimic Control Test"
Timeout: 10000
```

```await
Title: Control Observation (Benthic Listener)
Subject: Benthic Two
Contains: "Heard"
Contains: "Mimic Control Test"
Timeout: 10000
```

### Stage 3: Test Experiment (Benthic Speaks)
Benthic One speaks. We expect failure here if Benthic Mouth is broken.

```mimic Benthic One
CHAT Benthic Variable Test
```

```await
Title: Test Stimulus (Territory Received)
Subject: Territory
Contains: "sig": "FromVisitant"
Contains: "val": "Benthic Variable Test"
Timeout: 10000
```

```await
Title: Test Observation (Mimic Listener)
Subject: Mimic Two
Contains: "sig": "Heard"
Contains: "val": "From: Benthic One, Msg: Benthic Variable Test"
Timeout: 10000
```

```await
Title: Test Observation (Benthic Listener)
Subject: Benthic Two
Contains: "Heard"
Contains: "Benthic Variable Test"
Timeout: 10000
```

### Curtain Call
Exit.

```mimic Mimic One
LOGOUT
EXIT
```
```mimic Mimic Two
LOGOUT
EXIT
```
```mimic Benthic One
LOGOUT
EXIT
```
```mimic Benthic Two
LOGOUT
EXIT
```

```wait
2000
```

# Expedition Report: Benthic Chat TDD Verification

## 1. Summary of Findings
We successfully established a controlled environment (Stage 2) where `Mimic` instances demonstrated functional speech and hearing. Under these same conditions, `Benthic` instances failed to demonstrate either capability.

**Status:**
*   **Mimic (Control):** Ears OK, Mouth OK.
*   **Benthic (Test):** Ears BROKEN (Deaf), Mouth BROKEN (Mute).

## 2. Experimental Evidence

### A. The "Deafness" (Inbound Chat)
When `Mimic One` spoke "Mimic Control Test":
*   **Territory:** Received and broadcasted the message (Confirmed).
*   **Mimic Two:** Heard "Mimic Control Test" (Confirmed).
*   **Benthic Two:** **FAILED** to hear anything (Timeout).

**Code Analysis:**
*   `udp_handler.rs` appears to receive `PacketType::ChatFromSimulator` and forwards it via `mailbox_address.send(SendUIMessage { ui_message: UIMessage::new_chat_from_simulator(...) })`.
*   `deepsea_client/src/main.rs` has a handler for `UIMessage::ChatFromSimulator(chat)` which calls `log_encounter("Chat", "Heard", ...)`
*   **Hypothesis:** The disconnect likely lies in the internal message passing (Actor mailbox) or the packet deserialization before it reaches the UI actor. The logs show `unhandled packet` for `AgentMovementComplete` but are silent on Chat, suggesting it might not even be reaching the unhandled catch-all, or is being dropped silently.

### B. The "Muteness" (Outbound Chat)
When `Benthic One` attempted to speak "Benthic Variable Test":
*   **Territory:** **FAILED** to receive the message (Timeout).
*   **Mimic Two:** **FAILED** to hear the message (Timeout).

**Code Analysis:**
*   `deepsea_client` sends `Command::Chat(msg)` to the backend.
*   The backend is expected to convert this to a `ChatFromViewer` packet.
*   Since the Territory never heard it, the packet was likely never transmitted or was malformed.

## 3. Session Post-Mortem (The "Disaster")
*   **Incident:** Infinite loop while attempting to verify log contents via `grep` caused session instability.
*   **Recovery:** Halted execution as per directive. State preserved in this document.
*   **Artifacts:** This file (`benthic_TDD_chat.md`) acts as the sole artifact of the session. No other changes were committed.
