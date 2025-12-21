#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
VIVARIUM_DIR="$REPO_ROOT/vivarium"
OPENSIM_DIR="$VIVARIUM_DIR/opensim-core-0.9.3/bin"
MIMIC_DIR="$VIVARIUM_DIR/mimic"
ENSURE_DOTNET="$REPO_ROOT/instruments/substrate/ensure_dotnet.sh"
OBSERVATORY_DIR="$VIVARIUM_DIR/opensim-core-0.9.3/observatory"
STANDALONE_INI="$REPO_ROOT/species/opensim-core/standalone-observatory-sandbox.ini"

# Load Substrate
DOTNET_ROOT=$("$ENSURE_DOTNET") || exit 1
export DOTNET_ROOT
export PATH="$DOTNET_ROOT:$PATH"

echo "======================================================================"
echo "Encounter: OpenSim (Species) <=> Mimic (Instrument)"
echo "======================================================================"

if [ ! -d "$OPENSIM_DIR" ]; then
    echo "Error: OpenSim not found at $OPENSIM_DIR. Please acquire and incubate first."
    exit 1
fi

if [ ! -d "$MIMIC_DIR" ]; then
    echo "Error: Mimic not found at $MIMIC_DIR. Please build first."
    exit 1
fi

# 1. Setup Configuration
echo "[ENCOUNTER] Configuring OpenSim..."

# Ensure Observatory Directory Exists
if [ ! -d "$OBSERVATORY_DIR" ]; then
    echo "Creating Observatory at $OBSERVATORY_DIR..."
    mkdir -p "$OBSERVATORY_DIR/Regions"
    # Create encounter.ini with Estate Overrides
    cat > "$OBSERVATORY_DIR/encounter.ini" <<EOF
[Estates]
    DefaultEstateName = My Estate
    DefaultEstateOwnerName = Test User
    DefaultEstateOwnerUUID = 00000000-0000-0000-0000-000000000000
    DefaultEstateOwnerEMail = test@example.com
    DefaultEstateOwnerPassword = password
EOF
fi

# Ensure Regions.ini exists in Observatory
if [ ! -f "$OBSERVATORY_DIR/Regions/Regions.ini" ]; then
    echo "Copying default Regions.ini to Observatory..."
    cp "$OPENSIM_DIR/Regions/Regions.ini.example" "$OBSERVATORY_DIR/Regions/Regions.ini"
fi

cd "$OPENSIM_DIR"

# 2. Cleanup Logs & DB
echo "[ENCOUNTER] Cleaning up previous runs..."
rm -f "$VIVARIUM_DIR/encounter.log"
# We need to clean up logs in the OBSERVATORY_DIR too as that's where they are written now
rm -f "$OBSERVATORY_DIR/opensim.log"
rm -f "$OBSERVATORY_DIR/opensimstats.log"
# And databases
rm -f "$OBSERVATORY_DIR/"*.db
rm -f "$OBSERVATORY_DIR/console_history.txt"

# 3. Start OpenSim
echo "[ENCOUNTER] Starting OpenSim..."
# Redirect stdout/stderr to opensim.log in observatory for consistency with INI config
# Note: INI config sets logfile to ${CUSTOM|LOGDIR}/opensim.log which is OBSERVATORY_DIR
# But we also want to capture console output that might happen before logging starts or crash dumps.
# So we redirect to the same place or a wrapper log.
# Actually, let's redirect to a file in VIVARIUM_DIR or OBSERVATORY_DIR.
# The INI file specifies LOGDIR = ${Startup|inidirectory}, so opensim.log will be in OBSERVATORY_DIR.
# We will redirect stdout/stderr to there as well to catch everything.

dotnet OpenSim.dll \
    -inifile="$STANDALONE_INI" \
    -inidirectory="$OBSERVATORY_DIR" \
    > "$OBSERVATORY_DIR/opensim_console.log" 2>&1 &

OPENSIM_PID=$!
echo "[ENCOUNTER] OpenSim PID: $OPENSIM_PID"

# Wait for startup
echo "[ENCOUNTER] Waiting 20s for OpenSim to stabilize..."
sleep 20

# 4. Run Mimic
echo "[ENCOUNTER] Engaging Mimic..."
cd "$MIMIC_DIR"
# Mimic logs to ../encounter.log (vivarium/encounter.log)

# Run Mimic
# We need to make sure Mimic can find the grid.
# The standalone INI sets port 9000, localhost. Mimic defaults to this.
dotnet Mimic.dll --mode success || true

# 5. Stop OpenSim
echo "[ENCOUNTER] Terminating OpenSim..."
kill $OPENSIM_PID || true
wait $OPENSIM_PID || true

# 6. Verify
echo "[ENCOUNTER] Verifying Interaction..."
LOG_FILE="$VIVARIUM_DIR/encounter.log"
CONSOLE_LOG="$OBSERVATORY_DIR/opensim_console.log"

if [ -f "$LOG_FILE" ]; then
    echo "Found Encounter Log: $LOG_FILE"
    grep "LOGIN" "$LOG_FILE"
    grep "UDP" "$LOG_FILE"

    if grep -q "LOGIN] SUCCESS" "$LOG_FILE" && grep -q "UDP] CONNECTED" "$LOG_FILE"; then
        echo "SUCCESS: Irrefutable evidence of communication found."
    else
        echo "FAILURE: Could not find Login Success or UDP Connection in logs."
        echo "--- OpenSim Console Log (tail) ---"
        tail -n 50 "$CONSOLE_LOG"
        exit 1
    fi
else
    echo "FAILURE: No encounter log generated."
    echo "--- OpenSim Console Log (tail) ---"
    tail -n 50 "$CONSOLE_LOG"
    exit 1
fi

echo "Encounter Complete."
