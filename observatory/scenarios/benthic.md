# Benthic Encounter

A prototype encounter inviting Benthic Visitants into the Territory.

## 1. Environment Setup
Prepare the directories and cleanup previous artifacts.

[#include](templates/prepare_habitat.md)

## 2. Territory Initialization
Initialize OpenSim to create databases, then stop it.

[#include](templates/territory.opensim-core-0.9.3.initialize-simulation.md)

## 3. Opening Credits (Cast)

```cast
[
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
Start OpenSim again and wait for it to be ready.

```opensim
# Start Live
```
[#include](templates/territory.opensim-core-0.9.3.await-region.md)
[#include](templates/territory.opensim-core-0.9.3.await-login-service.md)

### Benthic One

```mimic Benthic One
# Benthic runs on autopilot
```

```await
Title: Benthic One Presence (Self)
Subject: Benthic One
Contains: "sig": "Success"
```

```await
Title: Benthic One Presence (Territory)
Subject: Territory
Contains: "sig": "VisitantLogin", "val": "Benthic One"
```

### Benthic Two

```mimic Benthic Two
# Benthic runs on autopilot
```

```await
Title: Benthic Two Presence (Self)
Subject: Benthic Two
Contains: "sig": "Success"
```

### Curtain Call

```opensim
QUIT
WAIT_FOR_EXIT
```
