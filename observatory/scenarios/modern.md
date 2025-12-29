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

```opensim
create user Visitant One password test@example.com 11111111-1111-1111-1111-111111111111 default
create user Visitant Two password test@example.com 22222222-2222-2222-2222-222222222222 default
```

```bash
# Verify users exist in DB (using python since sqlite3 cli might be missing)
python3 -c "import sqlite3, os, time; db_path=os.path.join(os.environ['OBSERVATORY_DIR'], 'userprofiles.db'); time.sleep(1); conn = sqlite3.connect(db_path); cursor = conn.cursor(); cursor.execute('SELECT Firstname, Lastname FROM UserAccounts'); print(cursor.fetchall()); conn.close()" > "$OBSERVATORY_DIR/users_check.txt"
```

```verify
Title: Verify User Creation
File: $OBSERVATORY_DIR/users_check.txt
Contains: Visitant', 'One
```

## 3. Opening Credits (Cast)
Disabled for Modern Encounter (using create user instead).

```json
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
Contains: "sig": "Success"
```

```await
Title: Visitant One Presence (Territory)
Subject: Territory
Contains: "sig": "VisitantLogin"
```

### Visitant Two: The Explorer
Visitant Two logs in, chats, and rezzes an object.

```mimic Visitant Two
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
