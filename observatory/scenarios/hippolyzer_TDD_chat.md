---
Title: Hippolyzer Client Integration & Smoke Test
ID: hippolyzer_TDD_chat
---

# Hippolyzer Client Integration

This scenario verifies the network capability of the `hippolyzer-client` species by introducing it to a controlled environment alongside a standard reference mimic.

## 1. Environment Setup
Prepare the directories and cleanup previous artifacts.

[#include](templates/prepare_habitat.md)

## 2. Territory Initialization
Initialize OpenSim.

[#include](templates/territory.initialize-simulation.md)

## 3. The Cast
We define two distinct actors to prevent log ambiguity:
1.  **Mimic Visitor** (Mimic): A known-good control agent.
2.  **Hippolyzer Client** (Hippolyzer-Client): The experimental subject.

```cast
[
    {
        "First": "Mimic",
        "Last": "Visitor",
        "Password": "password",
        "UUID": "11111111-1111-1111-1111-111111111111",
        "Species": "Mimic"
    },
    {
        "First": "Hippolyzer",
        "Last": "Client",
        "Password": "password",
        "UUID": "99999999-9999-9999-9999-999999999999",
        "Species": "hippolyzer-client"
    }
]
```

## 4. The Encounter

### Territory Live
Start the simulation.

```opensim
# Start Live
```
[#include](templates/territory.await-region.md)
[#include](templates/territory.await-login-service.md)

### Phase 1: Carrier Lock (Login)
Both agents enter the territory to establish presence.

```mimic Mimic Visitor
LOGIN Mimic Visitor password
```

```await
Title: Reference Presence (Territory Ack)
Subject: Territory
Contains: "sys": "MIGRATION", "sig": "ARRIVAL", "val": "Mimic Visitor"
```

```mimic Hippolyzer Client
LOGIN Hippolyzer Client password
```

```await
Title: Hippolyzer Presence (Territory Ack)
Subject: Territory
Contains: "sys": "MIGRATION", "sig": "ARRIVAL", "val": "Hippolyzer Client"
```

```await
Title: Visual Confirmation (Hippolyzer sees Beacon)
Subject: Hippolyzer Client
Query: entry.sys == 'SENSORY' and entry.sig == 'VISION' and matches(entry.val, 'Mimic Visitor')
```

### Phase 2: Downlink Test (Control -> Test)
The Mimic Visitor broadcasts a sync packet. We verify the Hippolyzer Client receives it. This confirms the Client's **Ears** are working.

```mimic Mimic Visitor
CHAT SYS_SYNC_ALPHA_01
```

```await
Title: Downlink Propagation (Territory)
Subject: Territory
Contains: "sig": "SIGNAL", "val": "SYS_SYNC_ALPHA_01"
Timeout: 5000
```

```await
Title: Downlink Reception (Client Rx)
Subject: Hippolyzer Client
Contains: "sys": "SENSORY", "sig": "AUDITION", "val": "From: Mimic Visitor, Msg: SYS_SYNC_ALPHA_01"
Timeout: 5000
```

### Phase 3: Uplink Test (Test -> Control)
The Hippolyzer Client broadcasts an acknowledgment. We verify the Mimic Visitor receives it. This confirms the Client's **Mouth** is working.

```mimic Hippolyzer Client
CHAT SYS_ACK_BETA_02
```

```await
Title: Uplink Propagation (Territory)
Subject: Territory
Contains: "sig": "FromVisitant", "val": "SYS_ACK_BETA_02"
Timeout: 5000
```

```await
Title: Uplink Reception (Control Rx)
Subject: Mimic Visitor
Contains: "sig": "Heard", "val": "From: Hippolyzer Client, Msg: SYS_ACK_BETA_02"
Timeout: 5000
```

### Phase 4: Teardown
Graceful disconnection.

```wait
300000
```

```mimic Hippolyzer Client
LOGOUT
EXIT
```

```mimic Mimic Visitor
LOGOUT
EXIT
```

```wait
2000