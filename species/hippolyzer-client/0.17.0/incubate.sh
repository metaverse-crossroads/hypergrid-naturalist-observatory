#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
VIVARIUM_DIR="$REPO_ROOT/vivarium"
TARGET_DIR="$VIVARIUM_DIR/hippolyzer-client-0.17.0"
VENV_DIR="$TARGET_DIR/venv"
CLIENT_SCRIPT_SRC="$SCRIPT_DIR/deepsea_client.py"
CLIENT_SCRIPT_DEST="$TARGET_DIR/deepsea_client.py"

# Prerequisite check
if [ ! -d "$VENV_DIR" ]; then
    echo "Error: Virtual environment not found. Please run acquire.sh first."
    exit 1
fi
if [ ! -s "$VENV_DIR/bin/activate" ]; then
    ls -l "$VENV_DIR/bin"
    echo "Error: Broken Virtual environment ("$VENV_DIR/bin/activate" not found). Please run acquire.sh first."
    exit 1
fi

echo "Incubating Hippolyzer Client Specimen..."

# Copy Deep Sea Client script
echo "Grafting Deep Sea Client logic..."
cp "$CLIENT_SCRIPT_SRC" "$CLIENT_SCRIPT_DEST"

# Verify Installation
echo "Verifying installation..."
source "$VENV_DIR/bin/activate"

if python3 -c "import hippolyzer; print('Hippolyzer verified')"; then
    echo "Observation: Hippolyzer package verified."
else
    echo "Error: Failed to import hippolyzer."
    exit 1
fi

echo "Incubation complete."
