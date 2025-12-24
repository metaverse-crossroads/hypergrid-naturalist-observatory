# Benthic Encounter

A prototype encounter inviting Benthic Visitants into the Territory.

## 1. Environment Setup

```bash
# Echo Options
echo "Encounter Options: $ENCOUNTER_OPTIONS" >&2

# Define paths
VIVARIUM="vivarium"
OBSERVATORY="$VIVARIUM/opensim-core-0.9.3/observatory"
OPENSIM_BIN="$VIVARIUM/opensim-core-0.9.3/bin"

# Cleanup
rm -f "$VIVARIUM/"encounter.benthic.*.log
rm -f "$OBSERVATORY/opensim.log"
rm -f "$OBSERVATORY/opensim_console.log"
rm -f "$OBSERVATORY/"*.db

# Create Observatory
mkdir -p "$OBSERVATORY/Regions"
if [ ! -f "$OBSERVATORY/encounter.ini" ]; then
    echo "[Estates]" > "$OBSERVATORY/encounter.ini"
    echo "DefaultEstateName = My Estate" >> "$OBSERVATORY/encounter.ini"
    echo "DefaultEstateOwnerName = Test User" >> "$OBSERVATORY/encounter.ini"
    echo "DefaultEstateOwnerUUID = 00000000-0000-0000-0000-000000000123" >> "$OBSERVATORY/encounter.ini"
    echo "DefaultEstateOwnerEMail = test@example.com" >> "$OBSERVATORY/encounter.ini"
    echo "DefaultEstateOwnerPassword = password" >> "$OBSERVATORY/encounter.ini"
fi

# Copy Regions
cp "$OPENSIM_BIN/Regions/Regions.ini.example" "$OBSERVATORY/Regions/Regions.ini"
```

## 2. Territory Initialization

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
