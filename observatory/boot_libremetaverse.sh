#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Source Observatory Environment
source "$REPO_ROOT/instruments/substrate/observatory_env.bash"
test -v VIVARIUM_DIR || { echo "Error: Environment not set"; exit 1; }

SIMULANT_FQN=$(jq -e -r '.registry[] | select(.genus == "libremetaverse") | "\(.genus)-\(.species)"' "$REPO_ROOT/species/manifest.json") || exit 1
BIN_DIR=$(jq -e -r '.registry[] | select(.genus == "libremetaverse") | (.bin_dir // "bin")' "$REPO_ROOT/species/manifest.json") || exit 1
EXECUTABLE=$(jq -e -r '.registry[] | select(.genus == "libremetaverse") | (.executable // "DeepSeaClient.dll")' "$REPO_ROOT/species/manifest.json") || exit 1

SPECIMEN_DIR="$VIVARIUM_DIR/$SIMULANT_FQN"
ENSURE_DOTNET="$REPO_ROOT/instruments/substrate/ensure_dotnet.sh"

# Artifact Path
BINARY_PATH="$SPECIMEN_DIR/$BIN_DIR/$EXECUTABLE"

# Ensure Environment
if [ ! -f "$ENSURE_DOTNET" ]; then
    echo "Error: ensure_dotnet.sh not found."
    exit 1
fi

DOTNET_ROOT=$("$ENSURE_DOTNET") || exit 1
export DOTNET_ROOT
export PATH="$DOTNET_ROOT:$PATH"

if [ ! -f "$BINARY_PATH" ]; then
    echo "Error: DeepSeaClient.dll not found at $BINARY_PATH"
    echo "Please run 'make libremetaverse' first."
    exit 1
fi

# Determine Arguments
# If no arguments provided, default to --repl
ARGS=("$@")
if [ ${#ARGS[@]} -eq 0 ]; then
    ARGS=("--repl")
fi

echo "[BOOT] Launching DeepSeaClient with args: ${ARGS[*]}"
exec dotnet "$BINARY_PATH" "${ARGS[@]}"
