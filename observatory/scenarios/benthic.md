# Benthic Encounter

A prototype encounter inviting Benthic Visitants into the Territory.

## 1. Environment Setup
Prepare the directories and cleanup previous artifacts.

[#include](templates/setup_environment.md)
[#include](templates/default_estate.md)

## 2. Territory Initialization
Initialize OpenSim to create databases, then stop it.

[#include](templates/init_territory.md)

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
[#include](templates/await_default_region.md)
[#include](templates/await_logins_enabled.md)

### Benthic One

```mimic Benthic One
# Benthic runs on autopilot
```

```await
Title: Benthic One Presence (Self)
File: vivarium/encounter.benthic.visitant.BenthicOne.log
Contains: "sig": "Success"
Frame: Benthic One
```

```await
Title: Benthic One Presence (Territory)
File: vivarium/encounter.benthic.territory.log
Contains: "sig": "VisitantLogin", "val": "Benthic One"
Frame: Territory
```

### Benthic Two

```mimic Benthic Two
# Benthic runs on autopilot
```

```await
Title: Benthic Two Presence (Self)
File: vivarium/encounter.benthic.visitant.BenthicTwo.log
Contains: "sig": "Success"
Frame: Benthic Two
```

### Curtain Call

```opensim
QUIT
WAIT_FOR_EXIT
```
