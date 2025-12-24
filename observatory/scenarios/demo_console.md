# Console Command Demo

Demonstrates controlling OpenSim via the Director's stdio-REPL capability, including user provisioning and sending alerts.

## 1. Environment Setup

```bash
# Define paths
VIVARIUM="vivarium"
OBSERVATORY="$VIVARIUM/opensim-core-0.9.3/observatory"
OPENSIM_BIN="$VIVARIUM/opensim-core-0.9.3/bin"

# Cleanup
rm -f "$VIVARIUM/"encounter.demo_console.*.log
rm -f "$OBSERVATORY/opensim_console.log"
rm -f "$OBSERVATORY/"*.db

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

Initialize databases.

```bash
echo "shutdown" > "$OPENSIM_DIR/startup_commands.txt"
```

```opensim
WAIT_FOR_EXIT
```

```bash
rm -f "$OPENSIM_DIR/startup_commands.txt"
```

## 3. Encounter

Start the territory.

```opensim
# Start Live
```

```await
Title: Territory Readiness
File: vivarium/opensim-core-0.9.3/observatory/opensim_console.log
Contains: LOGINS ENABLED
Frame: Territory
Timeout: 60000
```

### Provisioning
Create a user via the console.
We provide all arguments to avoid interactive prompts which can be tricky to synchronize.
Syntax: create user <first> <last> <pass> <email> <uuid> <model>

```opensim
create user Console Test password test@example.com 00000000-0000-0000-0000-111111111111 Default
```

### Visitant Login
Login with the new user.

```mimic Console Test
LOGIN Console Test password
```

```await
Title: Visitant Login Success
File: vivarium/encounter.demo_console.visitant.ConsoleTest.log
Contains: "sig": "Success"
Frame: Visitant
```

### Alert Test
Send an alert from the console.

```opensim
alert This is a console alert
```

```await
Title: Alert Received
File: vivarium/encounter.demo_console.visitant.ConsoleTest.log
Contains: "val": "This is a console alert
Frame: Visitant
```

### Shutdown

```mimic Console Test
LOGOUT
EXIT
```

```opensim
shutdown
```
