# Naturalist Observatory: Interspecies Encounters

## The Interop Scenario

This scenario observes the interaction between two distinct species of Visitants: the .NET-based Mimic and the Rust-based Benthic Deep Sea Variant.

## 1. Environment Setup

Prepare the directories and cleanup previous artifacts.

```bash
# Define paths
VIVARIUM="vivarium"
OBSERVATORY="$VIVARIUM/opensim-core-0.9.3/observatory"
OPENSIM_BIN="$VIVARIUM/opensim-core-0.9.3/bin"

# Cleanup
rm -f "$VIVARIUM/"encounter.interop.*.log
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
title: Territory Integrity (UserProfiles)
file: vivarium/opensim-core-0.9.3/observatory/userprofiles.db
contains: SQLite format 3
frame: Infrastructure
```

```verify
title: Territory Integrity (Inventory)
file: vivarium/opensim-core-0.9.3/observatory/inventory.db
contains: SQLite format 3
frame: Infrastructure
```

## 3. Preparation (Casting)

We introduce two Visitants to the range.

```cast
[
  {
    "First": "Mimic",
    "Last": "Observer",
    "Password": "secret",
    "UUID": "11111111-1111-1111-1111-111111111111",
    "Species": "Mimic"
  },
  {
    "First": "Benthic",
    "Last": "Explorer",
    "Password": "secret",
    "UUID": "22222222-2222-2222-2222-222222222222",
    "Species": "Benthic"
  }
]
```

## 4. The Encounter

Start the world and the visitants.

### Territory Live

```opensim
# Live
```

```await
title: Territory Initialization
file: vivarium/opensim-core-0.9.3/observatory/opensim_console.log
contains: LOGINS ENABLED
timeout: 60000
```

### 5. Interaction

Mimic enters first.

```mimic Mimic Observer
LOGIN Mimic Observer secret
```

```await
title: Mimic Login
file: vivarium/encounter.interop.visitant.MimicObserver.log
contains: "sig": "Success"
timeout: 30000
```

Benthic enters next.

```mimic Benthic Explorer
# Benthic arguments are handled via startup CLI injection by Director
# But we can verify its log
```

```await
title: Benthic Login
file: vivarium/encounter.interop.visitant.BenthicExplorer.log
contains: "sig": "Success"
timeout: 30000
```

### 6. Communication

Mimic speaks.

```mimic Mimic Observer
CHAT Hello Benthic, can you hear me?
```

Benthic should see Mimic (Presence).

```await
title: Benthic Sees Mimic
file: vivarium/encounter.interop.visitant.BenthicExplorer.log
contains: object update received: Avatar
timeout: 10000
```

(Note: Benthic currently does not support sending chat via CLI/stdin, so we only verify one-way or presence)

### 7. Departure

```mimic Mimic Observer
LOGOUT
EXIT
```

```opensim
QUIT
WAIT_FOR_EXIT
```
