#!/bin/bash
set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1
# Resolve Repo Root: SCRIPT_DIR is .../species/opensim-core/rest-console
# ../ is opensim-core, ../../ is species, ../../../ is root
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

# Source Observatory Environment
source "$REPO_ROOT/instruments/substrate/observatory_env.bash"
test -v VIVARIUM_DIR || { echo "Error: Environment not set"; exit 1; }

DAEMON_PY="$SCRIPT_DIR/console_daemon.py"

# Default Credentials
URL="${OPENSIM_URL:-http://127.0.0.1:9000}"
USER="${OPENSIM_USER:-RestUser}"
PASS="${OPENSIM_PASS:-RestPassword}"

# Parse Args
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --scenario) SCENARIO="$2"; shift ;;
        *) ;;
    esac
    shift
done

# Load from Synopsis if available
if [ -n "$SCENARIO" ]; then
    SYNOPSIS_FILE="$REPO_ROOT/vivarium/encounter.$SCENARIO.synopsis.json"
    if [ -f "$SYNOPSIS_FILE" ]; then
        if ! command -v python3 &> /dev/null; then
             echo "Warning: python3 not found, cannot parse synopsis." >&2
        else
            # Extract values using python
            read -r S_URL S_USER S_PASS <<< $(python3 -c "
import sys, json
try:
    d = json.load(open('$SYNOPSIS_FILE'))
    print(f\"{d.get('OpenSimURL', '')} {d.get('OpenSimUser', '')} {d.get('OpenSimPass', '')}\")
except: pass
")
            if [ -n "$S_URL" ] && [ "$S_URL" != " " ]; then URL="$S_URL"; fi
            if [ -n "$S_USER" ] && [ "$S_USER" != " " ]; then USER="$S_USER"; fi
            if [ -n "$S_PASS" ] && [ "$S_PASS" != " " ]; then PASS="$S_PASS"; fi

            echo "Loaded configuration from $SYNOPSIS_FILE" >&2
        fi
    else
        echo "Warning: Synopsis file $SYNOPSIS_FILE not found." >&2
    fi
fi

echo "Connecting to OpenSim Console at $URL as $USER" >&2

# Check dependencies
if ! command -v python3 &> /dev/null; then
    echo '{"error": "python3 not found"}'
    exit 1
fi

if [ ! -f "$DAEMON_PY" ]; then
    echo '{"error": "console_daemon.py not found"}'
    exit 1
fi

# Execute Daemon
exec python3 "$DAEMON_PY" --url "$URL" --user "$USER" --password "$PASS"
