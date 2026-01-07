#!/bin/bash
set -e

# Save current settings
export initial_stty=$(stty -g)
echo "initial_stty=$initial_stty" >&2

# Restore settings on any exit condition
shutdown() {
    trap '' EXIT SIGINT SIGTERM
    echo "SHUTDOWN $1... $initial_stty" >&2
    stty "$initial_stty"
}
trap 'shutdown EXIT' EXIT
trap 'shutdown SIGINT' SIGINT
trap 'shutdown SIGTERM' SIGTERM

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Source Observatory Environment
source "$REPO_ROOT/instruments/substrate/observatory_env.bash"
test -v VIVARIUM_DIR || { echo "Error: Environment not set"; exit 1; }

OPENSIM_CORE_DIR="$VIVARIUM_DIR/opensim-core-0.9.3"
OPENSIM_BIN="$OPENSIM_CORE_DIR/bin"
ENSURE_DOTNET="$REPO_ROOT/instruments/substrate/ensure_dotnet.sh"
SANDBOX_DIR="$OPENSIM_CORE_DIR/manual-sandbox"
STANDALONE_INI="$REPO_ROOT/species/opensim-core/standalone-observatory-sandbox.ini"

# Ensure Environment
if [ ! -f "$ENSURE_DOTNET" ]; then
    echo "Error: ensure_dotnet.sh not found."
    exit 1
fi

DOTNET_ROOT=$("$ENSURE_DOTNET") || exit 1
export DOTNET_ROOT
export PATH="$DOTNET_ROOT:$PATH"

if [ ! -f "$OPENSIM_BIN/OpenSim.dll" ]; then
    echo "Error: OpenSim.dll not found at $OPENSIM_BIN/OpenSim.dll"
    echo "Please run 'make opensim-core' first."
    exit 1
fi

# Prepare Manual Sandbox
echo "[BOOT] Preparing Manual Sandbox at $SANDBOX_DIR..."
mkdir -p "$SANDBOX_DIR/Regions"

# 1. Regions.ini
if true || [ ! -f "$SANDBOX_DIR/Regions/Regions.ini" ]; then
    cat <<EOF > "$SANDBOX_DIR/Regions/Regions.ini"
[Manual Sandbox]
    RegionUUID = 11111111-2222-3333-4444-555555555567
    Location = 1000,1000
    InternalAddress = 0.0.0.0
    InternalPort = ${OPENSIM_PORT:-9000}
    AllowAlternatePorts = False
    ExternalHostName = SYSTEMIP
EOF

    # if [ -f "$OPENSIM_BIN/Regions/Regions.ini.example" ]; then
    #     cp "$OPENSIM_BIN/Regions/Regions.ini.example" "$SANDBOX_DIR/Regions/Regions.ini"
    #     echo "[BOOT] Copied default Regions.ini"
    # else
    #     echo "[BOOT] Warning: Regions.ini.example not found."
    # fi
fi

# 2. encounter.ini (Estate Defaults)
if true || [ ! -f "$SANDBOX_DIR/encounter.ini" ]; then
    cat <<EOF > "$SANDBOX_DIR/encounter.ini"
[CUSTOM]
    GRIDNAME = "manual-sandbox"
    HOSTNAME = ${OPENSIM_HOSTNAME:-127.0.0.1}

[Network]
    ConsoleUser = "RestUser"
    ConsolePass = "RestPassword"

[GridService]
    Region_Manual_Sandbox = "DefaultRegion"

[Estates]
    DefaultEstateName = Manual Sandbox Estate
    DefaultEstateOwnerName = Test User
    DefaultEstateOwnerUUID = 00000000-0000-0000-0000-000000000123
    DefaultEstateOwnerEMail = test@example.com
    DefaultEstateOwnerPassword = password
EOF
    echo "[BOOT] Created default encounter.ini (Estate Owner: Test User / password)"
fi

# 3. Environment Variables for OpenSim
export OPENSIM_DIR="$OPENSIM_BIN"
export OBSERVATORY_DIR="$SANDBOX_DIR"
# Unset encounter log so it doesn't try to write to a stale file or fail
unset OPENSIM_ENCOUNTER_LOG

# Launch
echo "[BOOT] Launching OpenSim (Ctrl+C to quit)..."
echo "----------------------------------------------------------------"
cd "$OPENSIM_BIN"
dotnet OpenSim.dll \
    -inifile="$STANDALONE_INI" \
    -inidirectory="$SANDBOX_DIR" \
    "$@"
