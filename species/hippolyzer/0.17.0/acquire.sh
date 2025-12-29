#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
VIVARIUM_DIR="$REPO_ROOT/vivarium"
TARGET_DIR="$VIVARIUM_DIR/hippolyzer-0.17.0"
VENV_DIR="$TARGET_DIR/venv"

echo "Acquiring Hippolyzer Specimen (0.17.0)..."

# Ensure vivarium exists
mkdir -p "$TARGET_DIR"

# Create Virtual Environment
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment in $VENV_DIR..."
    python3 -m venv "$VENV_DIR"
else
    echo "Virtual environment already exists."
fi

# Activate and Install
echo "Installing dependencies..."
source "$VENV_DIR/bin/activate"

# Upgrade pip to avoid issues
pip install --upgrade pip

# Install hippolyzer and dependencies
# Version 0.17.0 as identified
pip install hippolyzer==0.17.0 mitmproxy outleap

echo "Acquisition complete: Hippolyzer 0.17.0 Specimen"
