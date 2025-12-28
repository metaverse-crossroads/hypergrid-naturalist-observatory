#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
VIVARIUM_DIR="$REPO_ROOT/vivarium"
SPECIMEN_DIR="$VIVARIUM_DIR/libremetaverse-2.0.0.278"
ENSURE_DOTNET="$REPO_ROOT/instruments/substrate/ensure_dotnet.sh"

# Artifact Path
BINARY_PATH="$SPECIMEN_DIR/DeepSeaClient_Build/bin/Release/net8.0/DeepSeaClient.dll"

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
