#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
VIVARIUM_DIR="$REPO_ROOT/vivarium"
MIMIC_DIR="$VIVARIUM_DIR/mimic"
ENSURE_DOTNET="$REPO_ROOT/instruments/substrate/ensure_dotnet.sh"

# Arguments
FIRST_NAME=${1:-Test}
LAST_NAME=${2:-User}
PASSWORD=${3:-password}
MODE=${4:-standard}
FLAGS=${5:-}

# Load Substrate
DOTNET_ROOT=$("$ENSURE_DOTNET")
export DOTNET_ROOT
export PATH="$DOTNET_ROOT:$PATH"

if [ ! -d "$MIMIC_DIR" ]; then
    echo "Error: Mimic not found at $MIMIC_DIR. Please build first."
    exit 1
fi

echo "[VISITANT] Running Mimic: $FIRST_NAME $LAST_NAME ($MODE) $FLAGS"
cd "$MIMIC_DIR"

# Run Mimic
# We use & to run in background if needed, but this script is just the runner.
# The caller should handle backgrounding.
dotnet Mimic.dll --user "$FIRST_NAME" --password "$PASSWORD" --mode "$MODE" $FLAGS
