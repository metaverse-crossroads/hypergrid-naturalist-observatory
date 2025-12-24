# Standard Encounter

This scenario replicates the legacy `run_encounter.sh` workflow using the new Literate Harness and "Naturalist Observatory" protocols.

## 1. Environment Setup
Prepare the directories and cleanup previous artifacts.

[#include](templates/setup_environment.md)
[#include](templates/default_estate.md)

## 2. Territory Initialization
Initialize OpenSim to create databases, then stop it.

[#include](templates/init_territory.md)

## 3. Opening Credits (Cast)
Now that databases exist, inject the Visitants.

```cast
[
    {
        "First": "Visitant",
        "Last": "One",
        "Password": "password",
        "UUID": "11111111-1111-1111-1111-111111111111"
    },
    {
        "First": "Visitant",
        "Last": "Two",
        "Password": "password",
        "UUID": "22222222-2222-2222-2222-222222222222"
    }
]
```

## 4. The Encounter
Start the world and the visitants.

### Territory Live
Start OpenSim again and wait for it to be ready.

```opensim
# Start Live
```
[#include](templates/await_default_region.md)
[#include](templates/await_logins_enabled.md)

### Visitant One: The Observer
Visitant One logs in and observes.

```mimic Visitant One
LOGIN Visitant One password
```

```await
Title: Visitant One Presence (Self)
File: vivarium/encounter.standard.visitant.VisitantOne.log
Contains: "sig": "Success"
Frame: Visitant One
```

```await
Title: Visitant One Presence (Territory)
File: vivarium/encounter.standard.territory.log
Contains: "sig": "VisitantLogin"
Frame: Territory
```

### Visitant Two: The Explorer
Visitant Two logs in, chats, and rezzes an object.

```mimic Visitant Two
LOGIN Visitant Two password
```

```await
Title: Visitant Two Presence (Self)
File: vivarium/encounter.standard.visitant.VisitantTwo.log
Contains: "sig": "Success"
Frame: Visitant Two
```

```await
Title: Visitant Two Presence (Territory)
File: vivarium/encounter.standard.territory.log
Contains: "sig": "VisitantLogin", "val": "Visitant Two"
Frame: Territory
```

```await
Title: Visitant Two Presence (Peer)
File: vivarium/encounter.standard.visitant.VisitantOne.log
Contains: "sig": "Presence Avatar"
Frame: Visitant One
```

```mimic Visitant Two
WAIT 2000
CHAT Hello? Is anyone out there?
REZ
```

### Observations
Verifying the causal chain of the vocalization.

```await
Title: Vocalization Stimulus (Sent)
File: vivarium/encounter.standard.visitant.VisitantTwo.log
Contains: "sig": "Heard"
Frame: Visitant Two (Self)
Timeout: 60000
```

```await
Title: Vocalization Observation (Territory)
File: vivarium/encounter.standard.territory.log
Contains: "sig": "FromVisitant"
Frame: Territory
Timeout: 60000
```

```await
Title: Vocalization Observation (Heard)
File: vivarium/encounter.standard.visitant.VisitantOne.log
Contains: "sig": "Heard"
Frame: Visitant One (Peer)
Timeout: 60000
```

```await
Title: Visual Confirmation (Rez)
File: vivarium/encounter.standard.visitant.VisitantOne.log
Contains: "sig": "Presence Thing"
Frame: Visitant One (Peer)
```

### Curtain Call
Logout.

```mimic Visitant Two
LOGOUT
EXIT
```

```mimic Visitant One
LOGOUT
EXIT
```

```wait
2000
```
