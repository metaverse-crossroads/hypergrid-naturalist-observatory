#!/bin/bash
# species/libremetaverse/2.0.0.278/run_visitant.sh
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

# Source Observatory Environment
source "$REPO_ROOT/instruments/substrate/observatory_env.bash"
test -v VIVARIUM_DIR || { echo "Error: Environment not set"; exit 1; }

VIVARIUM_DIR="$REPO_ROOT/vivarium"
SPECIMEN_DIR="$VIVARIUM_DIR/libremetaverse-2.5.7.90"
ENSURE_DOTNET="$REPO_ROOT/instruments/substrate/ensure_dotnet.sh"

# The compiled artifact is a DLL in the build directory
BINARY_PATH="$SPECIMEN_DIR/DeepSeaClient_Build/bin/Release/net8.0/DeepSeaClient.dll"

if [ ! -f "$BINARY_PATH" ]; then
    echo "Error: DeepSeaClient binary not found at:"
    echo "  $BINARY_PATH"
    echo "Please run incubate.sh first."
    exit 1
fi

# Load Substrate
DOTNET_ROOT=$("$ENSURE_DOTNET") || exit 1
export DOTNET_ROOT
export PATH="$DOTNET_ROOT:$PATH"

# Execute
exec dotnet "$BINARY_PATH" "$@"
