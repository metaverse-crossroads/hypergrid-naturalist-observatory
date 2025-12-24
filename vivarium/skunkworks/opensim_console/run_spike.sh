#!/bin/bash
set -e

# Config
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
VIVARIUM="$REPO_ROOT/vivarium"
OBSERVATORY="$VIVARIUM/opensim-core-0.9.3/observatory"
OPENSIM_BIN="$VIVARIUM/opensim-core-0.9.3/bin"
SKUNKWORKS="$VIVARIUM/skunkworks/opensim_console"
INI_FILE="$SKUNKWORKS/rest_console.ini"
CLIENT_PY="$SKUNKWORKS/rest_client.py"

# Ensure environment (Invoke in subshell and capture path)
DOTNET_ROOT=$("$REPO_ROOT/instruments/substrate/ensure_dotnet.sh") || exit 1
export PATH="$DOTNET_ROOT:$PATH"
export DOTNET_ROOT

echo "[SPIKE] Setting up Observatory..."
mkdir -p "$OBSERVATORY/Regions"

# Ensure basic configuration exists (borrowed from standard setup)
if [ ! -f "$OBSERVATORY/encounter.ini" ]; then
    echo "[Estates]" > "$OBSERVATORY/encounter.ini"
    echo "DefaultEstateName = My Estate" >> "$OBSERVATORY/encounter.ini"
    echo "DefaultEstateOwnerName = Test User" >> "$OBSERVATORY/encounter.ini"
    echo "DefaultEstateOwnerUUID = 00000000-0000-0000-0000-000000000123" >> "$OBSERVATORY/encounter.ini"
    echo "DefaultEstateOwnerEMail = test@example.com" >> "$OBSERVATORY/encounter.ini"
    echo "DefaultEstateOwnerPassword = password" >> "$OBSERVATORY/encounter.ini"
fi

if [ ! -f "$OBSERVATORY/Regions/Regions.ini" ]; then
    cp "$OPENSIM_BIN/Regions/Regions.ini.example" "$OBSERVATORY/Regions/Regions.ini"
fi

# Copy REST config
echo "[SPIKE] Injecting REST configuration..."
cp "$INI_FILE" "$OBSERVATORY/rest_console.ini"

# Cleanup Logs
rm -f "$OBSERVATORY/opensim.log"

# Start OpenSim
echo "[SPIKE] Starting OpenSim..."
pushd "$OPENSIM_BIN" > /dev/null
dotnet OpenSim.dll \
    -inifile="$REPO_ROOT/species/opensim-core/standalone-observatory-sandbox.ini" \
    -inidirectory="$OBSERVATORY" > "$SKUNKWORKS/opensim_stdout.log" 2>&1 &
OPENSIM_PID=$!
popd > /dev/null

echo "[SPIKE] OpenSim PID: $OPENSIM_PID"

# Wait for Port 9000
echo "[SPIKE] Waiting for port 9000..."
MAX_RETRIES=60
count=0
while ! curl -s http://127.0.0.1:9000/StartSession > /dev/null 2>&1; do
    if lsof -i :9000 > /dev/null; then
        break
    fi

    sleep 1
    count=$((count+1))
    if [ $count -ge $MAX_RETRIES ]; then
        echo "[SPIKE] Timeout waiting for OpenSim."
        # Print tail of log
        tail -n 20 "$SKUNKWORKS/opensim_stdout.log"
        kill $OPENSIM_PID || true
        exit 1
    fi
done

echo "[SPIKE] OpenSim is UP."
sleep 5 # Give it a moment to settle

# Run Tests
echo "[SPIKE] Running REST Client Tests..."

echo "--- TEST 1: Authentication & Help ---"
python3 "$CLIENT_PY" --url http://127.0.0.1:9000 --user RestUser --pass RestPassword --exec "help" > "$SKUNKWORKS/test_help.log" 2>&1 || echo "Test 1 Failed"

echo "--- TEST 2: Alert ---"
python3 "$CLIENT_PY" --url http://127.0.0.1:9000 --user RestUser --pass RestPassword --exec "alert ThisIsARestAlert" > "$SKUNKWORKS/test_alert.log" 2>&1 || echo "Test 2 Failed"

echo "--- TEST 3: Show Users ---"
python3 "$CLIENT_PY" --url http://127.0.0.1:9000 --user RestUser --pass RestPassword --exec "show users" > "$SKUNKWORKS/test_users.log" 2>&1 || echo "Test 3 Failed"

echo "--- TEST 4: Raw Output Inspection ---"
python3 "$CLIENT_PY" --url http://127.0.0.1:9000 --user RestUser --pass RestPassword --exec "help" --raw > "$SKUNKWORKS/test_raw.xml" 2>&1 || echo "Test 4 Failed"

# Cleanup
echo "[SPIKE] Stopping OpenSim..."
kill $OPENSIM_PID || true
wait $OPENSIM_PID 2>/dev/null || true

echo "[SPIKE] Done. Artifacts in $SKUNKWORKS"
