#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
VIVARIUM_DIR="$REPO_ROOT/vivarium"
OPENSIM_DIR="$VIVARIUM_DIR/opensim-core-0.9.3/bin"
MIMIC_DIR="$VIVARIUM_DIR/mimic"
ENSURE_DOTNET="$REPO_ROOT/instruments/substrate/ensure_dotnet.sh"

# Load Substrate
DOTNET_ROOT=$("$ENSURE_DOTNET")
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
cd "$OPENSIM_DIR"

# Copy Configs
[ ! -f OpenSim.ini ] && cp OpenSim.ini.example OpenSim.ini
[ ! -f config-include/StandaloneCommon.ini ] && cp config-include/StandaloneCommon.ini.example config-include/StandaloneCommon.ini
[ ! -f Regions/Regions.ini ] && cp Regions/Regions.ini.example Regions/Regions.ini

# Apply Estate Settings (Idempotent sed)
sed -i 's/; DefaultEstateName = My Estate/DefaultEstateName = My Estate/' OpenSim.ini
sed -i 's/; DefaultEstateOwnerName = FirstName LastName/DefaultEstateOwnerName = Test User/' OpenSim.ini
sed -i 's/; DefaultEstateOwnerUUID = .*/DefaultEstateOwnerUUID = 00000000-0000-0000-0000-000000000000/' OpenSim.ini
sed -i 's/; DefaultEstateOwnerEMail = .*/DefaultEstateOwnerEMail = test@example.com/' OpenSim.ini
sed -i 's/; DefaultEstateOwnerPassword = .*/DefaultEstateOwnerPassword = password/' OpenSim.ini

# 2. Cleanup Logs & DB
echo "[ENCOUNTER] Cleaning up previous runs..."
rm -f encounter.log
rm -f opensim.log
rm -f OpenSim.db
rm -f OpenSim.Log.db

# 3. Start OpenSim
echo "[ENCOUNTER] Starting OpenSim..."
# Redirect both stdout and stderr to opensim.log
dotnet OpenSim.dll > opensim.log 2>&1 &
OPENSIM_PID=$!
echo "[ENCOUNTER] OpenSim PID: $OPENSIM_PID"

# Wait for startup
echo "[ENCOUNTER] Waiting 20s for OpenSim to stabilize..."
sleep 20

# 4. Run Mimic
echo "[ENCOUNTER] Engaging Mimic..."
# Copy log4net config if needed, Mimic expects it in CWD or next to binary
# We run from MIMIC_DIR
cd "$MIMIC_DIR"
# Mimic logs to ../encounter.log (vivarium/encounter.log)
# We can't rely on ../encounter.log relative to MIMIC_DIR if we are in MIMIC_DIR.
# But Mimic.cs has `private static string LogPath = "../encounter.log";`
# So if we run in MIMIC_DIR, it writes to vivarium/encounter.log.

# Run Mimic
dotnet Mimic.dll --mode success || true

# 5. Stop OpenSim
echo "[ENCOUNTER] Terminating OpenSim..."
kill $OPENSIM_PID || true
wait $OPENSIM_PID || true

# 6. Verify
echo "[ENCOUNTER] Verifying Interaction..."
LOG_FILE="$VIVARIUM_DIR/encounter.log"

if [ -f "$LOG_FILE" ]; then
    echo "Found Encounter Log: $LOG_FILE"
    grep "LOGIN" "$LOG_FILE"
    grep "UDP" "$LOG_FILE"

    if grep -q "LOGIN] SUCCESS" "$LOG_FILE" && grep -q "UDP] CONNECTED" "$LOG_FILE"; then
        echo "SUCCESS: Irrefutable evidence of communication found."
    else
        echo "FAILURE: Could not find Login Success or UDP Connection in logs."
        exit 1
    fi
else
    echo "FAILURE: No encounter log generated."
    exit 1
fi

echo "Encounter Complete."
