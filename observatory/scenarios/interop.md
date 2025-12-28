# Interop Encounter

A mixed-species encounter with Mimic (C#) and Benthic (Rust) Visitants.

## 1. Environment Setup

[#include](templates/prepare_habitat.md)

## 2. Territory Initialization

[#include](templates/territory.initialize-simulation.md)

## 3. Opening Credits (Cast)

```cast
[
    {
        "First": "Visitant",
        "Last": "One",
        "Password": "password",
        "UUID": "11111111-1111-1111-1111-111111111111"
    },
    {
        "First": "Benthic",
        "Last": "One",
        "Password": "password",
        "UUID": "33333333-3333-3333-3333-333333333333",
        "Species": "Benthic"
    }
]
```

## 4. The Encounter

### Territory Live

```opensim
# Start Live
```
[#include](templates/territory.await-region.md)
[#include](templates/territory.await-login-service.md)

### Visitant One (Mimic)

```mimic Visitant One
LOGIN Visitant One password
WAIT 2000
CHAT Hello from the surface!
```

### Benthic One (Rust)

```mimic Benthic One
# Benthic runs on autopilot
```

```await
Title: Benthic One Presence (Territory)
Subject: Territory
Contains: "sig": "VisitantLogin", "val": "Benthic One"
```

```await
Title: Visitant One Heard Benthic
Subject: Visitant One
Contains: "sig": "Heard", "val": "Benthic One"
# Benthic doesn't chat yet, but if it did...
Timeout: 5000
```
