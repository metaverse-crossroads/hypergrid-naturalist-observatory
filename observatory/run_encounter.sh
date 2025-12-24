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

python3 "$DIRECTOR" "$SCENARIO"
