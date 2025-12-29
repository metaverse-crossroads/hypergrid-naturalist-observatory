#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
MIMIC_DIR="$REPO_ROOT/vivarium/mimic"
ENSURE_DOTNET="$REPO_ROOT/instruments/substrate/ensure_dotnet.sh"

# Load Substrate
source "$REPO_ROOT/instruments/substrate/observatory_env.bash"
test -v VIVARIUM_DIR || { echo "Error: Environment not set"; exit 1; }

DOTNET_ROOT=$("$ENSURE_DOTNET") || exit 1
export DOTNET_ROOT
export PATH="$DOTNET_ROOT:$PATH"

if [ ! -d "$MIMIC_DIR" ]; then
    echo "Error: Mimic not found at $MIMIC_DIR. Please build first."
    exit 1
fi

cd "$MIMIC_DIR"
echo "[VISITANT] Running with args: $@"
dotnet Mimic.dll "$@"
