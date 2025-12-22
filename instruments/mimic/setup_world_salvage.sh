#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
MIMIC_DIR="$REPO_ROOT/vivarium/mimic"
SEQUENCER_DIR="$REPO_ROOT/vivarium/sequencer"
SEQUENCER_DLL="$SEQUENCER_DIR/Sequencer.dll"
OBSERVATORY_DIR="$REPO_ROOT/vivarium/opensim-core-0.9.3/observatory"
ENSURE_DOTNET="$REPO_ROOT/instruments/substrate/ensure_dotnet.sh"

# Load Substrate
DOTNET_ROOT=$("$ENSURE_DOTNET") || exit 1
export DOTNET_ROOT
export PATH="$DOTNET_ROOT:$PATH"

# Ensure sqlite3 is installed
if ! command -v sqlite3 &> /dev/null; then
    echo "Error: sqlite3 required"
    exit 1
fi

if [ ! -f "$OBSERVATORY_DIR/userprofiles.db" ]; then
    echo "Error: Database files not found in $OBSERVATORY_DIR. OpenSim must be run at least once."
    exit 1
fi

# Build Sequencer if missing
if [ ! -f "$SEQUENCER_DLL" ]; then
    echo "Building Sequencer..."
    "$REPO_ROOT/instruments/sequencer/build.sh" || exit 1
fi

echo "Generating World Data..."
mkdir -p "$MIMIC_DIR"
OUTPUT_SQL="$MIMIC_DIR/world_data.sql"
> "$OUTPUT_SQL" # Clear file

# Visitant One
dotnet "$SEQUENCER_DLL" gen-user --first "Visitant" --last "One" --pass "password" --uuid "aa5ea169-321b-4632-b4fa-50933f3013f1" >> "$OUTPUT_SQL" || exit 1

# Visitant Two
dotnet "$SEQUENCER_DLL" gen-user --first "Visitant" --last "Two" --pass "password" --uuid "bb5ea169-321b-4632-b4fa-50933f3013f2" >> "$OUTPUT_SQL" || exit 1

# Object Injection (Owned by Visitant One)
dotnet "$SEQUENCER_DLL" gen-prim --owner "aa5ea169-321b-4632-b4fa-50933f3013f1" --region "11111111-2222-3333-4444-555555555555" --posX 128 --posY 128 --posZ 40 >> "$OUTPUT_SQL" || exit 1


# Filter and Apply
echo "Injecting Users..."
grep "INTO UserAccounts" "$OUTPUT_SQL" | sqlite3 "$OBSERVATORY_DIR/userprofiles.db"
grep "INTO auth" "$OUTPUT_SQL" | sqlite3 "$OBSERVATORY_DIR/auth.db"
grep "INTO inventoryfolders" "$OUTPUT_SQL" | sqlite3 "$OBSERVATORY_DIR/inventory.db"

echo "Injecting Objects..."
grep "INTO prims " "$OUTPUT_SQL" | sqlite3 "$OBSERVATORY_DIR/OpenSim.db"
grep "INTO primshapes" "$OUTPUT_SQL" | sqlite3 "$OBSERVATORY_DIR/OpenSim.db"

echo "World Setup Complete."
