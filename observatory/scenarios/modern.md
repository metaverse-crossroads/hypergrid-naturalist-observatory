---
Title: Modern Encounter
ID: modern
---

# Modern Encounter

This scenario replicates the legacy `run_encounter.sh` workflow using the new Literate Harness and "Naturalist Observatory" protocols.

## 1. Environment Setup
Prepare the directories and cleanup previous artifacts.

[#include](templates/prepare_habitat.md)

## 2. Territory Initialization
Initialize OpenSim and create users.

<!--
FIXME: This inline initialization block is a temporary measure to establish the "modern"
create-user pattern without burying details in templates. The intent is to eventually refactor
implementation details into a parametric cast-like feature.
-->

```opensim
# Start OpenSim
```

[#include](templates/territory.await-region.md)
[#include](templates/territory.await-login-service.md)

## 3. Opening Credits (Cast)
Casting the Visitants (using create user strategy).

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

### Visitant One: The Observer
Visitant One logs in and observes.

```mimic Visitant One
LOGIN Visitant One password
```

```await
Title: Visitant One Presence (Self)
Subject: Visitant One
Contains: "sys": "MIGRATION", "sig": "ENTRY"
Timeout: 4000
```

```await
Title: Visitant One Presence (Territory)
Subject: Territory
Contains: "sys": "MIGRATION", "sig": "ARRIVAL"
Timeout: 4000
```

### Visitant Two: The Explorer
Visitant Two logs in, chats, and rezzes an object.

```mimic Visitant Two
LOGIN Visitant Two password
```

```await
Title: Visitant Two Presence (Self)
Subject: Visitant Two
Contains: "sys": "MIGRATION", "sig": "ENTRY"
Timeout: 4000
```

```await
Title: Visitant Two Presence (Territory)
Subject: Territory
Contains: "sys": "MIGRATION", "sig": "ARRIVAL", "val": "Visitant Two"
Timeout: 4000
```

```await
Title: Visitant Two Presence (Peer)
Subject: Visitant One
Contains: "sys": "SENSORY", "sig": "VISION"
Timeout: 4000
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
Subject: Visitant Two
Contains: "sys": "SENSORY", "sig": "AUDITION"
Timeout: 4000
```

```await
Title: Vocalization Observation (Territory)
Subject: Territory
Contains: "sys": "TERRITORY", "sig": "SIGNAL", "val": "Hello? Is anyone out there?"
Timeout: 4000
```

```await
Title: Vocalization Observation (Heard)
Subject: Visitant One
Query: entry.sys == 'SENSORY' and entry.sig == 'AUDITION' and matches(entry.val, 'From: Visitant Two, Msg: Hello')
# Contains: "sys": "SENSORY", "sig": "AUDITION", "val": "From: Visitant Two, Msg: Hello? Is anyone out there?"
Timeout: 4000
```

```await
Title: Visual Confirmation (Rez)
Subject: Visitant One
Query: entry.sys == 'SENSORY' and entry.sig == 'VISION' and matches(entry.val, 'Thing')
Timeout: 8000
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
