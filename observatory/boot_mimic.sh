#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Source Observatory Environment
source "$REPO_ROOT/instruments/substrate/observatory_env.bash"
test -v VIVARIUM_DIR || { echo "Error: Environment not set"; exit 1; }

MIMIC_DIR="$VIVARIUM_DIR/mimic"
BINARY_PATH="$MIMIC_DIR/Mimic.dll"
ENSURE_DOTNET="$REPO_ROOT/instruments/substrate/ensure_dotnet.sh"

# Ensure Environment
if [ ! -f "$ENSURE_DOTNET" ]; then
    echo "Error: ensure_dotnet.sh not found."
    exit 1
fi

DOTNET_ROOT=$("$ENSURE_DOTNET") || exit 1
export DOTNET_ROOT
export PATH="$DOTNET_ROOT:$PATH"

if [ ! -f "$BINARY_PATH" ]; then
    echo "Error: Mimic.dll not found at $BINARY_PATH"
    echo "Please run 'make mimic' first."
    exit 1
fi

# Determine Arguments
# If no arguments provided, default to --repl
ARGS=("$@")
if [ ${#ARGS[@]} -eq 0 ]; then
    ARGS=("--repl")
fi

cd "$MIMIC_DIR"
echo "[BOOT] Launching Mimic with args: ${ARGS[*]}"
exec dotnet "$BINARY_PATH" "${ARGS[@]}"
