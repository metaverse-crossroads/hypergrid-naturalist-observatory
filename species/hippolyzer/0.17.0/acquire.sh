#!/bin/bash
set -eu

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
VIVARIUM_DIR="$REPO_ROOT/vivarium"
TARGET_DIR="$VIVARIUM_DIR/hippolyzer-0.17.0"
VENV_DIR="$TARGET_DIR/venv"
XPYTHONEXECUTABLE=${PYTHONEXECUTABLE:-python}
unset PYTHONEXECUTABLE
unset PIP_PYTHON

echo "Acquiring Hippolyzer Specimen (0.17.0)..."

# Ensure vivarium exists
mkdir -p "$TARGET_DIR"

# Create Virtual Environment
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment in $VENV_DIR... using $XPYTHONEXECUTABLE"
    set -x
    $XPYTHONEXECUTABLE -m venv "$VENV_DIR"
else
    echo "Virtual environment already exists."
fi
unset XPYTHONEXECUTABLE

echo "Verifying virtual environment in $VENV_DIR..."
if [ ! -s "$VENV_DIR/bin/activate" ]; then
    ls -l "$VENV_DIR/bin"
    echo "Error: Broken Virtual environment ("$VENV_DIR/bin/activate" not found). Please run acquire.sh first."
    exit 1
fi

$VENV_DIR/bin/python -mensurepip
PIP_PYTHON=$VENV_DIR/bin/python

echo "Installing dependencies..."

$VENV_DIR/bin/python -mpip install hippolyzer==0.17.0 mitmproxy outleap

echo "Acquisition complete: Hippolyzer 0.17.0 Specimen"
