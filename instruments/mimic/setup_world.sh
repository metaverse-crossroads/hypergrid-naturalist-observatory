#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
MIMIC_DIR="$REPO_ROOT/vivarium/mimic"
OBSERVATORY_DIR="$REPO_ROOT/vivarium/opensim-core-0.9.3/observatory"
ENSURE_DOTNET="$REPO_ROOT/instruments/substrate/ensure_dotnet.sh"

# Load Substrate
DOTNET_ROOT=$("$ENSURE_DOTNET") || exit 1
export DOTNET_ROOT
export PATH="$DOTNET_ROOT:$PATH"

# Ensure sqlite3 is installed
if ! command -v sqlite3 &> /dev/null; then
    echo "sqlite3 not found. Installing..."
    sudo apt-get update && sudo apt-get install -y sqlite3
fi

if [ ! -f "$OBSERVATORY_DIR/userprofiles.db" ]; then
    echo "Error: Database files not found in $OBSERVATORY_DIR. OpenSim must be run at least once."
    exit 1
fi

echo "Generating World Data..."
cd "$MIMIC_DIR"
dotnet Mimic.dll --mode gen-data > "$MIMIC_DIR/world_data.sql"

# Filter and Apply
echo "Injecting Users..."
grep "INTO UserAccounts" "$MIMIC_DIR/world_data.sql" | sqlite3 "$OBSERVATORY_DIR/userprofiles.db"
grep "INTO auth" "$MIMIC_DIR/world_data.sql" | sqlite3 "$OBSERVATORY_DIR/auth.db"
grep "INTO inventoryfolders" "$MIMIC_DIR/world_data.sql" | sqlite3 "$OBSERVATORY_DIR/inventory.db"

echo "Injecting Objects..."
grep "INTO prims " "$MIMIC_DIR/world_data.sql" | sqlite3 "$OBSERVATORY_DIR/OpenSim.db"
grep "INTO primshapes" "$MIMIC_DIR/world_data.sql" | sqlite3 "$OBSERVATORY_DIR/OpenSim.db"

echo "World Setup Complete."
