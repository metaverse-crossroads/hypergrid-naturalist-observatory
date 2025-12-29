#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

# Source Observatory Environment
source "$REPO_ROOT/instruments/substrate/observatory_env.bash"
test -v VIVARIUM_DIR || { echo "Error: Environment not set"; exit 1; }

VIVARIUM_DIR="$REPO_ROOT/vivarium"
TARGET_DIR="$VIVARIUM_DIR/hippolyzer-client-0.17.0"
VENV_DIR="$TARGET_DIR/venv"
CLIENT_SCRIPT="$TARGET_DIR/deepsea_client.py"

if [ ! -f "$CLIENT_SCRIPT" ]; then
    echo "Error: DeepSeaClient script not found at:"
    echo "  $CLIENT_SCRIPT"
    echo "Please run incubate.sh first."
    exit 1
fi

# Activate
source "$VENV_DIR/bin/activate"

# Execute
exec python3 "$CLIENT_SCRIPT" "$@"
