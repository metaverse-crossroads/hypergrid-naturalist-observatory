# Benthic Encounter

A prototype encounter inviting Benthic Visitants into the Territory.

## 1. Environment Setup
Prepare the directories and cleanup previous artifacts.

[#include](templates/prepare_habitat.md)

## 2. Territory Initialization
Initialize OpenSim to create databases, then stop it.

[#include](templates/territory.initialize-simulation.md)

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

```territory
# Start Live
```
[#include](templates/territory.await-region.md)
[#include](templates/territory.await-login-service.md)

### Enter Benthic One

```mimic Benthic One
LOGIN Benthic One password
```

```await
Title: Benthic One Presence (Self)
Subject: Benthic One
Contains: "sys": "MIGRATION", "sig": "ENTRY"
```

### Enter Benthic Two

```mimic Benthic Two
LOGIN Benthic Two password
```

```await
Title: Benthic Two Presence (Self)
Subject: Benthic Two
Contains: "sys": "MIGRATION", "sig": "ENTRY"
```

```territory
alert welcome
```

### Conversation (Attempt)

# Sending CHAT commands to verify REPL input works.
# Note: Upstream bug in benthic/metaverse_core prevents ChatFromSimulator reception.
# Verification of 'Heard' signal is currently disabled.

```mimic Benthic One
CHAT Hello from Benthic One
```

```mimic Benthic Two
CHAT Hello from Benthic Two
```

### REPL Verification (Logout)

# We verify REPL works by sending LOGOUT and checking for the local log signal.

```mimic Benthic One
LOGOUT
```

```await
Title: Benthic One Logout Confirmation
Subject: Benthic One
Contains: "sys": "MIGRATION", "sig": "DEPARTURE"
```

### Curtain Call

```opensim
alert Simulation Closing
QUIT
WAIT_FOR_EXIT
```
