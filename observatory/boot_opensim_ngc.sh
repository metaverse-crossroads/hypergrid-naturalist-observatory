#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Source Observatory Environment
source "$REPO_ROOT/instruments/substrate/observatory_env.bash"
test -v VIVARIUM_DIR || { echo "Error: Environment not set"; exit 1; }

OPENSIM_CORE_DIR="$VIVARIUM_DIR/opensim-ngc-0.9.3"
OPENSIM_BIN="$OPENSIM_CORE_DIR/build/Release"
ENSURE_DOTNET="$REPO_ROOT/instruments/substrate/ensure_dotnet.sh"
SANDBOX_DIR="$OPENSIM_CORE_DIR/manual-sandbox"
STANDALONE_INI="$REPO_ROOT/species/opensim-ngc/standalone-observatory-sandbox.ini"

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
    echo "Please run 'make opensim-ngc' first."
    exit 1
fi

# Prepare Manual Sandbox
echo "[BOOT] Preparing Manual Sandbox at $SANDBOX_DIR..."
mkdir -p "$SANDBOX_DIR/Regions"

# 1. Regions.ini
if [ ! -f "$SANDBOX_DIR/Regions/Regions.ini" ]; then
    if [ -f "$OPENSIM_BIN/Regions/Regions.ini.example" ]; then
        cp "$OPENSIM_BIN/Regions/Regions.ini.example" "$SANDBOX_DIR/Regions/Regions.ini"
        echo "[BOOT] Copied default Regions.ini"
    else
        echo "[BOOT] Warning: Regions.ini.example not found."
    fi
fi

# 2. encounter.ini (Estate Defaults)
if [ ! -f "$SANDBOX_DIR/encounter.ini" ]; then
    cat <<EOF > "$SANDBOX_DIR/encounter.ini"
[Estates]
DefaultEstateName = Manual Sandbox Estate
DefaultEstateOwnerName = Test User
DefaultEstateOwnerUUID = 00000000-0000-0000-0000-000000000123
DefaultEstateOwnerEMail = test@example.com
DefaultEstateOwnerPassword = password
EOF
    echo "[BOOT] Created default encounter.ini (Owner: Test User / password)"
fi

if [ ! -f "$SANDBOX_DIR/ngc.ini" ]; then
    cat <<EOF > "$SANDBOX_DIR/ngc.ini"

[Startup]
    physics = basicphysics

[UserAccountService]
    StorageProvider = "OpenSim.Data.Null.dll"

EOF
    echo "[BOOT] Created default ngc.ini (basicphysics / nullstorage)"
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
exec dotnet OpenSim.dll \
    -inifile="$STANDALONE_INI" \
    -inidirectory="$SANDBOX_DIR"
