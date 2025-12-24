#!/bin/bash
set -e

# Config
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
VIVARIUM="$REPO_ROOT/vivarium"
OBSERVATORY="$VIVARIUM/opensim-core-0.9.3/observatory"
OPENSIM_BIN="$VIVARIUM/opensim-core-0.9.3/bin"
SKUNKWORKS="$VIVARIUM/skunkworks/opensim_console"
INI_FILE="$SKUNKWORKS/rest_console.ini"
CONNECT_SCRIPT="$SKUNKWORKS/connect_opensim_console_session.sh"

# Ensure environment
DOTNET_ROOT=$("$REPO_ROOT/instruments/substrate/ensure_dotnet.sh") || exit 1
export PATH="$DOTNET_ROOT:$PATH"
export DOTNET_ROOT

echo "[SPIKE V2] Setting up Observatory..."
mkdir -p "$OBSERVATORY/Regions"

# Ensure config
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

cp "$INI_FILE" "$OBSERVATORY/rest_console.ini"
rm -f "$OBSERVATORY/opensim.log"

# Start OpenSim
echo "[SPIKE V2] Starting OpenSim..."
pushd "$OPENSIM_BIN" > /dev/null
dotnet OpenSim.dll \
    -inifile="$REPO_ROOT/species/opensim-core/standalone-observatory-sandbox.ini" \
    -inidirectory="$OBSERVATORY" > "$SKUNKWORKS/opensim_stdout_v2.log" 2>&1 &
OPENSIM_PID=$!
popd > /dev/null

echo "[SPIKE V2] OpenSim PID: $OPENSIM_PID"

# Wait for Port 9000
echo "[SPIKE V2] Waiting for port 9000..."
MAX_RETRIES=60
count=0
while ! curl -s http://127.0.0.1:9000/StartSession > /dev/null 2>&1; do
    if lsof -i :9000 > /dev/null; then
        break
    fi
    sleep 1
    count=$((count+1))
    if [ $count -ge $MAX_RETRIES ]; then
        echo "[SPIKE V2] Timeout waiting for OpenSim."
        kill $OPENSIM_PID || true
        exit 1
    fi
done

echo "[SPIKE V2] OpenSim is UP."
sleep 5

# Run Test
echo "[SPIKE V2] Connecting and sending commands..."
$CONNECT_SCRIPT <<EOF > "$SKUNKWORKS/spike_v2_output.json"
help
show users
EOF

echo "[SPIKE V2] Output:"
cat "$SKUNKWORKS/spike_v2_output.json"

# Cleanup
echo "[SPIKE V2] Stopping OpenSim..."
kill $OPENSIM_PID || true
wait $OPENSIM_PID 2>/dev/null || true

echo "[SPIKE V2] Done."
