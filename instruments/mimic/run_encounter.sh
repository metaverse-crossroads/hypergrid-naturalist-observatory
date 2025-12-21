#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
VIVARIUM_DIR="$REPO_ROOT/vivarium"
OPENSIM_DIR="$VIVARIUM_DIR/opensim-core-0.9.3/bin"
MIMIC_DIR="$VIVARIUM_DIR/mimic"
ENSURE_DOTNET="$REPO_ROOT/instruments/substrate/ensure_dotnet.sh"
SETUP_SCRIPT="$SCRIPT_DIR/setup_encounter.sh"
RUN_VISITANT="$SCRIPT_DIR/run_visitant.sh"

# Load Substrate
DOTNET_ROOT=$("$ENSURE_DOTNET")
export DOTNET_ROOT
export PATH="$DOTNET_ROOT:$PATH"

echo "======================================================================"
echo "Encounter: OpenSim (Species) <=> Mimic (Instrument)"
echo "======================================================================"

# 1. Run Setup
bash "$SETUP_SCRIPT"

# 2. Cleanup Logs & DB
echo "[ENCOUNTER] Cleaning up previous runs..."
rm -f "$VIVARIUM_DIR/encounter.log"
cd "$OPENSIM_DIR"
rm -f opensim.log
rm -f OpenSim.db
rm -f OpenSim.Log.db

# 3. Start OpenSim
echo "[ENCOUNTER] Starting OpenSim..."
dotnet OpenSim.dll > opensim.log 2>&1 &
OPENSIM_PID=$!
echo "[ENCOUNTER] OpenSim PID: $OPENSIM_PID"

# Wait for startup
echo "[ENCOUNTER] Waiting 30s for OpenSim to stabilize..."
sleep 30

# 4. Run Visitants
echo "[ENCOUNTER] Engaging Visitant 1 (Observer)..."
# Run first user (Observer/Logger)
bash "$RUN_VISITANT" "Test" "User" "password" "standard" &
VISITANT1_PID=$!

echo "[ENCOUNTER] Waiting 10s..."
sleep 10

echo "[ENCOUNTER] Engaging Visitant 2 (Actor)..."
# Run second user (Actor - Rezzes Object & Chats)
# Note: User 2 was created by setup_encounter.sh (via startup_commands.txt)
bash "$RUN_VISITANT" "Test" "User2" "test2@example.com" "chatter" "--rez" &
VISITANT2_PID=$!

# Wait for interaction
echo "[ENCOUNTER] Waiting 20s for interaction..."
sleep 20

# 5. Stop OpenSim
echo "[ENCOUNTER] Terminating OpenSim..."
kill $OPENSIM_PID || true
wait $OPENSIM_PID || true
kill $VISITANT1_PID || true
kill $VISITANT2_PID || true

# 6. Verify
echo "[ENCOUNTER] Verifying Interaction..."
LOG_FILE="$VIVARIUM_DIR/encounter.log"

if [ -f "$LOG_FILE" ]; then
    echo "Found Encounter Log: $LOG_FILE"

    # Check for enhanced field marks
    echo "Checking for 'Where' (Region Handshake)..."
    grep "REGION" "$LOG_FILE" || echo "WARN: No Region info logged"

    echo "Checking for 'Chattering'..."
    grep "CHAT" "$LOG_FILE" || echo "WARN: No Chat logged"

    echo "Checking for 'Things' (Presence)..."
    grep "SIGHT] PRESENCE Thing" "$LOG_FILE" || echo "WARN: No Objects seen"

    echo "Checking for 'Avatars' (Presence)..."
    grep "SIGHT] PRESENCE Avatar" "$LOG_FILE" || echo "WARN: No Avatars seen"

    if grep -q "LOGIN] SUCCESS" "$LOG_FILE" && grep -q "UDP] CONNECTED" "$LOG_FILE"; then
        echo "SUCCESS: Basic communication found."
    else
        echo "FAILURE: Could not find Login Success or UDP Connection in logs."
        exit 1
    fi
else
    echo "FAILURE: No encounter log generated."
    exit 1
fi

echo "Encounter Complete."
