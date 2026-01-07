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

[#include](templates/territory.initialize-simulation.md)

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
[#include](templates/territory.await-region.md)
<!-- [#include](templates/territory.await-login-service.md) -->

### Stage 1: Arrival
All visitants enter the territory.

```mimic Mimic One
LOGIN Mimic One password
```
```await
Title: Mimic One Present
Subject: Territory
Contains: "val": "Mimic One"
Timeout: 4000
```

```mimic Mimic Two
LOGIN Mimic Two password
```
```await
Title: Mimic Two Present
Subject: Territory
Contains: "val": "Mimic Two"
Timeout: 4000
```

```mimic Benthic One
LOGIN Benthic One password
```
```await
Title: Benthic One Present
Subject: Territory
Contains: "val": "Benthic One"
Timeout: 4000
```

```mimic Benthic Two
LOGIN Benthic Two password
```

```await
Title: Benthic Two Present
Subject: Territory
Contains: "val": "Benthic Two"
Timeout: 4000
```
```wait
2000
```
```await
Title: All Visitants Present
Subject: Territory
Contains: "val": "Mimic One"
Contains: "val": "Mimic Two"
Contains: "val": "Benthic One"
Contains: "val": "Benthic Two"
Timeout: 2000
```

```wait
2000
```

### Stage 2: Control Experiment (Mimic Speaks)
Mimic One speaks. We expect everyone with working ears to hear it.

```mimic Mimic One
CHAT MimicOneSaid
```

```await
Title: Mimic One Heard
Subject: Territory
Contains: "sys": "TERRITORY", "sig": "SIGNAL"
Contains: "val": "MimicOneSaid"
Timeout: 2000
```

```await
Title: Mimic One Heard
Subject: Mimic Two
Contains: "sys": "SENSORY", "sig": "AUDITION"
Contains: "val": "From: Mimic One, Msg: MimicOneSaid"
Timeout: 2000
```

```await
Title: Mimic One Heard
Subject: Benthic Two
Contains: "sys": "SENSORY", "sig": "AUDITION"
Contains: "val": "From: Mimic One, Msg: MimicOneSaid"
Timeout: 2000
```

### Stage 3: Test Experiment (Benthic Speaks)
Benthic One speaks. We expect failure here if Benthic Mouth is broken.

```mimic Benthic One
CHAT Benthic Variable Test
```

```await
Title: Benthoc One Heard
Subject: Territory
Contains: "sys": "TERRITORY", "sig": "SIGNAL"
Contains: "val": "Benthic Variable Test"
Timeout: 2000
```

```await
Title: Benthoc One Heard
Subject: Mimic Two
Contains: "sys": "SENSORY", "sig": "AUDITION"
Contains: "val": "From: Benthic One, Msg: Benthic Variable Test"
Timeout: 2000
```

```await
Title: Benthoc One Heard
Subject: Benthic Two
Contains: "sys": "SENSORY", "sig": "AUDITION"
Contains: "val": "From: Benthic One, Msg: Benthic Variable Test"
Timeout: 2000
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
