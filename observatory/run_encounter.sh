#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DIRECTOR="$SCRIPT_DIR/director.py"

echo "======================================================================"
echo "Encounter: OpenSim (Species) <=> Mimic/Benthic (Instrument)"
echo "Mode: Literate Scenario"
echo "======================================================================"

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <scenario.md> [-- options...]"
    exit 1
fi

SCENARIO="$1"
shift

# Handle options after --
ENCOUNTER_OPTIONS=""
if [[ "$1" == "--" ]]; then
    shift
    ENCOUNTER_OPTIONS="$@"
fi

export ENCOUNTER_OPTIONS

if [ ! -f "$DIRECTOR" ]; then
    echo "Error: Director not found at $DIRECTOR"
    exit 1
fi

if [ ! -f "$SCENARIO" ]; then
    # Try resolving relative to SCRIPT_DIR if not found
    if [ -f "$SCRIPT_DIR/$SCENARIO" ]; then
        SCENARIO="$SCRIPT_DIR/$SCENARIO"
    else
        echo "Error: Scenario not found at $SCENARIO"
        exit 1
    fi
fi

echo "Scenario: $SCENARIO"
if [ -n "$ENCOUNTER_OPTIONS" ]; then
    echo "Options: $ENCOUNTER_OPTIONS"
fi

# Trap Cleanup
# Track Python PID
PYTHON_PID=""

cleanup() {
    echo ""
    echo "[ENCOUNTER] Trapped Signal. Waiting for Director to cleanup..."
    if [ -n "$PYTHON_PID" ]; then
        # Director (Python) receives the signal directly from the OS (same process group).
        # We wait for it to exit gracefully.

        local timeout=5
        local count=0
        while ps -p $PYTHON_PID > /dev/null && [ $count -lt $timeout ]; do
            sleep 1
            count=$((count + 1))
        done

        if ps -p $PYTHON_PID > /dev/null; then
             echo "[ENCOUNTER] Director stuck. Sending SIGTERM..."
             kill -TERM $PYTHON_PID 2>/dev/null || true
             sleep 2
             if ps -p $PYTHON_PID > /dev/null; then
                 echo "[ENCOUNTER] Director still running. Force killing..."
                 kill -9 $PYTHON_PID 2>/dev/null || true
             fi
        fi
    fi
    # Wait for all background jobs
    wait 2>/dev/null || true
    echo "[ENCOUNTER] Cleanup complete."
}

trap cleanup SIGINT SIGTERM

python3 "$DIRECTOR" "$SCENARIO" &
PYTHON_PID=$!

wait $PYTHON_PID
EXIT_CODE=$?

exit $EXIT_CODE
