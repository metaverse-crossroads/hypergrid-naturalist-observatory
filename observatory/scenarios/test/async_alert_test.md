---
Title: Test Async Sensors (Alert)
---

# Test Async Sensors (Alert)

**Purpose:** Verify that an `async-sensor` can monitor a log file and trigger an `director#alert`, which is then received by a Visitant.

## 1. Environment Setup

[#include](../templates/prepare_habitat.md)

## 2. Territory Initialization

[#include](../templates/territory.initialize-simulation.md)

## 3. Opening Credits (Cast)

```cast
[
    {
        "First": "Stand",
        "Last": "In",
        "Password": "password",
        "UUID": "11111111-1111-1111-1111-111111111111",
        "Species": "mimic"
    }
]
```

## 4. The Encounter

### Territory Live
Start OpenSim.

```territory
# Start Live
```
[#include](../templates/territory.await-region.md)
[#include](../templates/territory.await-login-service.md)

### Configure Sensor

```async-sensor
Title: Alert Trigger Sensor
Subject: Territory
Contains: TRIGGER_ALERT
director#alert: ALERT_RECEIVED
```

### Visitant Login & Trigger

```actor Stand In
LOGIN Stand In password
```

```await
Title: Stand In Login
Subject: Stand In
Contains: "MIGRATION", "ENTRY"
```

```actor Stand In
CHAT TRIGGER_ALERT
```

```await
Title: Trigger Chat Observed (Territory)
Subject: Territory
Contains: TRIGGER_ALERT
Timeout: 10000
```

### Verify Alert Reception

```await
Title: Alert Received by Visitant
Subject: Stand In
Contains: ALERT_RECEIVED
Timeout: 10000
```

### Curtain Call

```actor Stand In
LOGOUT
EXIT
```

```wait
2000
```
