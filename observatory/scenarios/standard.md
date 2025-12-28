---
Title: Standard Encounter
ID: standard
---

# Standard Encounter

This scenario replicates the legacy `run_encounter.sh` workflow using the new Literate Harness and "Naturalist Observatory" protocols.

## 1. Environment Setup
Prepare the directories and cleanup previous artifacts.

[#include](templates/prepare_habitat.md)

## 2. Territory Initialization
Initialize OpenSim to create databases, then stop it.

[#include](templates/territory.initialize-simulation.md)

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

```territory
# Start Live
```
[#include](templates/territory.await-region.md)
[#include](templates/territory.await-login-service.md)

### Visitant One: The Observer
Visitant One logs in and observes.

```actor Visitant One
LOGIN Visitant One password
```

```await
Title: Visitant One Presence (Self)
Subject: Visitant One
Contains: "sig": "Success"
```

```await
Title: Visitant One Presence (Territory)
Subject: Territory
Contains: "sig": "VisitantLogin"
```

### Visitant Two: The Explorer
Visitant Two logs in, chats, and rezzes an object.

```actor Visitant Two
LOGIN Visitant Two password
```

```await
Title: Visitant Two Presence (Self)
Subject: Visitant Two
Contains: "sig": "Success"
```

```await
Title: Visitant Two Presence (Territory)
Subject: Territory
Contains: "sig": "VisitantLogin", "val": "Visitant Two"
```

```await
Title: Visitant Two Presence (Peer)
Subject: Visitant One
Contains: "sig": "Presence Avatar"
```

```actor Visitant Two
WAIT 2000
CHAT Hello? Is anyone out there?
REZ
```

### Observations
Verifying the causal chain of the vocalization.

```await
Title: Vocalization Stimulus (Sent)
Subject: Visitant Two
Contains: "sig": "Heard"
Timeout: 60000
```

```await
Title: Vocalization Observation (Territory)
Subject: Territory
Contains: "sig": "FromVisitant"
Timeout: 60000
```

```await
Title: Vocalization Observation (Heard)
Subject: Visitant One
Contains: "sig": "Heard"
Timeout: 60000
```

```await
Title: Visual Confirmation (Rez)
Subject: Visitant One
Contains: "sig": "Presence Thing"
```

### Curtain Call
Logout.

```actor Visitant Two
LOGOUT
EXIT
```

```actor Visitant One
LOGOUT
EXIT
```

```wait
2000
```
