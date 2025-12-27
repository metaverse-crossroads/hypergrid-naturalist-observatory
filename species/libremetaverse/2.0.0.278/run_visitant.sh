#!/usr/bin/env bash
# species/libremetaverse/2.0.0.278/run_visitant.sh
# Wrapper to run the DeepSeaClient.

set -e

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
VIVARIUM_DIR="$REPO_ROOT/vivarium/libremetaverse-2.0.0.278"
# The build output for DeepSeaClient will be in src/bin/Release/net8.0/DeepSeaClient.dll
CLIENT_DLL="$VIVARIUM_DIR/src/bin/Release/net8.0/DeepSeaClient.dll"
ENSURE_DOTNET="$REPO_ROOT/instruments/substrate/ensure_dotnet.sh"

# --- Substrate ---
DOTNET_ROOT=$("$ENSURE_DOTNET") || exit 1
export PATH="$DOTNET_ROOT:$PATH"

# --- Run ---
if [ ! -f "$CLIENT_DLL" ]; then
    echo "DeepSeaClient.dll not found. Please run incubate.sh first."
    exit 1
fi

echo "[VISITANT] Running DeepSeaClient..."
exec dotnet "$CLIENT_DLL" "$@"
