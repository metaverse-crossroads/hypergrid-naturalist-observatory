# Standard Encounter

This scenario replicates the legacy `run_encounter.sh` workflow using the new Literate Harness and "Naturalist Observatory" protocols.

## 1. Environment Setup
Prepare the directories and cleanup previous artifacts.

```bash
# Define paths
VIVARIUM="vivarium"
OBSERVATORY="$VIVARIUM/opensim-core-0.9.3/observatory"
OPENSIM_BIN="$VIVARIUM/opensim-core-0.9.3/bin"

# Cleanup
rm -f "$VIVARIUM/encounter.log"
rm -f "$OBSERVATORY/opensim.log"
rm -f "$OBSERVATORY/opensim_console.log"
rm -f "$OBSERVATORY/"*.db
rm -f "$VIVARIUM/"mimic_*.log

# Create Observatory
mkdir -p "$OBSERVATORY/Regions"
if [ ! -f "$OBSERVATORY/encounter.ini" ]; then
    echo "[Estates]" > "$OBSERVATORY/encounter.ini"
    echo "DefaultEstateName = My Estate" >> "$OBSERVATORY/encounter.ini"
    echo "DefaultEstateOwnerName = Test User" >> "$OBSERVATORY/encounter.ini"
    echo "DefaultEstateOwnerUUID = 00000000-0000-0000-0000-000000000000" >> "$OBSERVATORY/encounter.ini"
    echo "DefaultEstateOwnerEMail = test@example.com" >> "$OBSERVATORY/encounter.ini"
    echo "DefaultEstateOwnerPassword = password" >> "$OBSERVATORY/encounter.ini"
fi

# Copy Regions
cp "$OPENSIM_BIN/Regions/Regions.ini.example" "$OBSERVATORY/Regions/Regions.ini"
```

## 2. Territory Initialization
Initialize OpenSim to create databases, then stop it.

```bash
# Create startup commands to auto-shutdown after init
echo "shutdown" > "$OPENSIM_DIR/startup_commands.txt"
```

```opensim
# Start OpenSim to initialize DBs (will auto-shutdown)
WAIT_FOR_EXIT
```

```bash
# Remove startup commands so Live session stays up
rm -f "$OPENSIM_DIR/startup_commands.txt"
```

```verify
Title: Territory Integrity (UserProfiles)
File: vivarium/opensim-core-0.9.3/observatory/userprofiles.db
Contains: SQLite format 3
Frame: Infrastructure
```

```verify
Title: Territory Integrity (Inventory)
File: vivarium/opensim-core-0.9.3/observatory/inventory.db
Contains: SQLite format 3
Frame: Infrastructure
```

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
Start the world and the actors.

### Territory Live
Start OpenSim again and wait for it to be ready.

```opensim
# Live
```

```await
Title: Territory Readiness
File: vivarium/opensim-core-0.9.3/observatory/opensim_console.log
Contains: LOGINS ENABLED
Frame: Territory
Timeout: 60000
```

### Visitant One: The Observer
Visitant One logs in and observes.

```mimic Visitant One
LOGIN Visitant One password
```

```await
Title: Visitant One Presence
File: vivarium/mimic_Visitant_One.log
Contains: [LOGIN] SUCCESS
Frame: Visitant One
```

### Visitant Two: The Actor
Visitant Two logs in, chats, and rezzes an object.

```mimic Visitant Two
LOGIN Visitant Two password
```

```await
Title: Visitant Two Presence
File: vivarium/mimic_Visitant_Two.log
Contains: [LOGIN] SUCCESS
Frame: Visitant Two
```

```mimic Visitant Two
WAIT 2000
CHAT "Observation unit online. Vocalization test successful."
REZ
```

### Observations
Verifying the causal chain of the vocalization.

```await
Title: Vocalization Stimulus (Sent)
File: vivarium/mimic_Visitant_Two.log
Contains: [CHAT] HEARD | From: Visitant Two, Msg: "Observation unit online. Vocalization test successful."
Frame: Visitant Two (Self)
```

```await
Title: Vocalization Observation (Heard)
File: vivarium/mimic_Visitant_One.log
Contains: [CHAT] HEARD | From: Visitant Two, Msg: "Observation unit online. Vocalization test successful."
Frame: Visitant One (Peer)
```

```await
Title: Visual Confirmation (Rez)
File: vivarium/mimic_Visitant_One.log
Contains: [SIGHT] PRESENCE Thing
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
