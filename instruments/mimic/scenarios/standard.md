# Standard Encounter

This scenario replicates the legacy `run_encounter.sh` workflow using the new Literate Harness.

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
rm -f "$OBSERVATORY/"*.db
rm -f "$VIVARIUM/"visitant_*.log

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

# Verify Infrastructure (Databases)
if [ ! -f "$OBSERVATORY_DIR/userprofiles.db" ]; then
    echo "CRITICAL FAILURE: userprofiles.db was not created."
    exit 1
fi
if [ ! -f "$OBSERVATORY_DIR/auth.db" ]; then
    echo "CRITICAL FAILURE: auth.db was not created."
    exit 1
fi
if [ ! -f "$OBSERVATORY_DIR/inventory.db" ]; then
    echo "CRITICAL FAILURE: inventory.db was not created."
    exit 1
fi
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

```bash
# Verify Cast Integrity (Pre-flight)
python3 -c "
import sqlite3, sys, os
db_path = os.path.join(os.environ['OBSERVATORY_DIR'], 'userprofiles.db')
if not os.path.exists(db_path):
    print(f'FAILURE: DB {db_path} missing.')
    sys.exit(1)
try:
    conn = sqlite3.connect(db_path)
    c = conn.cursor()
    uuids = ['11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222']
    for uuid in uuids:
        c.execute('SELECT PrincipalID FROM UserAccounts WHERE PrincipalID=?', (uuid,))
        if not c.fetchone():
            print(f'FAILURE: Visitant {uuid} missing from database.')
            sys.exit(1)
    print('VERIFICATION PASSED: All Visitants accounted for in Database.')
except Exception as e:
    print(f'FAILURE: Database check failed: {e}')
    sys.exit(1)
"
```

## 4. The Encounter
Start the world and the actors.

### Territory Live
Start OpenSim again.

```opensim
# Live
```

```wait
20000
```

### Visitant One: The Observer
Visitant One logs in and observes.

```mimic Visitant One
LOGIN Visitant One password
```

```wait
2000
```

### Visitant Two: The Actor
Visitant Two logs in, chats, and rezzes an object.

```mimic Visitant Two
LOGIN Visitant Two password
WAIT 2000
CHAT "Observation unit online. Vocalization test successful."
REZ
```

### Duration
Let the encounter breathe for a moment.

```wait
5000
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

```bash
# Verify Scenario Success
# Check if at least one Visitant logged in successfully
if grep -Fq "[LOGIN] SUCCESS" vivarium/mimic_*.log; then
    echo "VERIFICATION PASSED: MIMIC LOGIN SUCCESSFUL"
else
    echo "VERIFICATION FAILED: NO SUCCESSFUL LOGINS FOUND"
    exit 1
fi
```
