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
SETUP_WORLD="$SCRIPT_DIR/setup_world.sh"
RUN_VISITANT="$SCRIPT_DIR/run_visitant.sh"

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

# 2. Cleanup Logs & DB (Fresh Start)
echo "[ENCOUNTER] Cleaning up previous runs..."
rm -f "$VIVARIUM_DIR/encounter.log"
rm -f "$OBSERVATORY_DIR/opensim.log"
rm -f "$OBSERVATORY_DIR/opensimstats.log"
rm -f "$OBSERVATORY_DIR/"*.db
rm -f "$OBSERVATORY_DIR/console_history.txt"

# 3. Initialize Databases (Start, Wait, Stop)
echo "[ENCOUNTER] Initializing Databases..."
dotnet OpenSim.dll \
    -inifile="$STANDALONE_INI" \
    -inidirectory="$OBSERVATORY_DIR" \
    > "$OBSERVATORY_DIR/opensim_console_init.log" 2>&1 &

OPENSIM_INIT_PID=$!
echo "[ENCOUNTER] OpenSim Init PID: $OPENSIM_INIT_PID"

echo "[ENCOUNTER] Waiting 20s for DB initialization..."
sleep 20

echo "[ENCOUNTER] Stopping OpenSim Init..."
kill $OPENSIM_INIT_PID || true
wait $OPENSIM_INIT_PID || true

# 4. Inject World Data
echo "[ENCOUNTER] Injecting World Data..."
"$SETUP_WORLD"

# 5. Start OpenSim (Live)
echo "[ENCOUNTER] Starting OpenSim (Live)..."
dotnet OpenSim.dll \
    -inifile="$STANDALONE_INI" \
    -inidirectory="$OBSERVATORY_DIR" \
    > "$OBSERVATORY_DIR/opensim_console.log" 2>&1 &

OPENSIM_PID=$!
echo "[ENCOUNTER] OpenSim Live PID: $OPENSIM_PID"
echo "[ENCOUNTER] Waiting 20s for OpenSim to stabilize..."
sleep 20

# 6. Run Visitants
echo "[ENCOUNTER] Engaging Visitants..."

# Visitant 1: Visitant One (Created via SQL)
"$RUN_VISITANT" --user "Visitant" --lastname "One" --password "password" --mode success > "$VIVARIUM_DIR/visitant_1.log" 2>&1 &
PID_1=$!

sleep 2

# Visitant 2: Visitant Two (Created via SQL)
"$RUN_VISITANT" --user "Visitant" --lastname "Two" --password "password" --mode success > "$VIVARIUM_DIR/visitant_2.log" 2>&1 &
PID_2=$!

# Waiting for Visitants
wait $PID_1
wait $PID_2

# 7. Stop OpenSim
echo "[ENCOUNTER] Terminating OpenSim..."
kill $OPENSIM_PID || true
wait $OPENSIM_PID || true

# 8. Verify
echo "[ENCOUNTER] Verifying Interaction..."
VISITANT_1_LOG="$VIVARIUM_DIR/visitant_1.log"
VISITANT_2_LOG="$VIVARIUM_DIR/visitant_2.log"
CONSOLE_LOG="$OBSERVATORY_DIR/opensim_console.log"

# Verify Visitant One
if [ -f "$VISITANT_1_LOG" ]; then
    if grep -q "LOGIN] SUCCESS | Agent: aa5ea169-321b-4632-b4fa-50933f3013f1" "$VISITANT_1_LOG"; then
        echo "SUCCESS: Visitant One logged in."
    else
        echo "FAILURE: Visitant One failed."
        echo "--- Visitant One Log ---"
        cat "$VISITANT_1_LOG"
        FAILED=1
    fi
else
    echo "FAILURE: Visitant One log missing."
    FAILED=1
fi

# Verify Visitant Two
if [ -f "$VISITANT_2_LOG" ]; then
    if grep -q "LOGIN] SUCCESS | Agent: bb5ea169-321b-4632-b4fa-50933f3013f2" "$VISITANT_2_LOG"; then
        echo "SUCCESS: Visitant Two logged in."
    else
        echo "FAILURE: Visitant Two failed."
        echo "--- Visitant Two Log ---"
        cat "$VISITANT_2_LOG"
        FAILED=1
    fi
else
    echo "FAILURE: Visitant Two log missing."
    FAILED=1
fi

if [ "$FAILED" == "1" ]; then
    echo "--- OpenSim Console Log (tail) ---"
    tail -n 50 "$CONSOLE_LOG"
    exit 1
fi

echo "Encounter Complete."
