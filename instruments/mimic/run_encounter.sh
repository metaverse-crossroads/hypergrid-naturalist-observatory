#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
DIRECTOR="$SCRIPT_DIR/director.py"
SCENARIO="$SCRIPT_DIR/scenarios/standard.md"

# Load Substrate (Python needs it?)
# director.py handles loading dotnet env internally, but we need python3.
# Assuming python3 is available in environment.

echo "======================================================================"
echo "Encounter: OpenSim (Species) <=> Mimic (Instrument)"
echo "Mode: Literate Scenario ($SCENARIO)"
echo "======================================================================"

if [ ! -f "$DIRECTOR" ]; then
    echo "Error: Director not found at $DIRECTOR"
    exit 1
fi

if [ ! -f "$SCENARIO" ]; then
    echo "Error: Scenario not found at $SCENARIO"
    exit 1
fi

python3 "$DIRECTOR" "$SCENARIO"
