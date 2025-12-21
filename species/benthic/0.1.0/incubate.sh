#!/usr/bin/env bash
set -e

# Resolve the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SPECIMEN_DIR="$REPO_ROOT/vivarium/benthic-0.1.0/metaverse_client"

# 1. Prerequisite: Check if specimen exists
if [ ! -d "$SPECIMEN_DIR" ]; then
    echo "Observation: Specimen missing. Please run acquire.sh first."
    exit 1
fi

# 2. Substrate: Call ensure_rust.sh
ENSURE_RUST="$REPO_ROOT/instruments/substrate/ensure_rust.sh"
if [ ! -x "$ENSURE_RUST" ]; then
    echo "Error: Substrate script not found or not executable at $ENSURE_RUST"
    exit 1
fi

# Capture the output of ensure_rust.sh (which is CARGO_HOME)
# CRITICAL: Use || exit 1 to catch failures in subshell
CARGO_HOME_PATH=$("$ENSURE_RUST") || exit 1

# 3. Activate
export CARGO_HOME="$CARGO_HOME_PATH"
export PATH="$CARGO_HOME/bin:$PATH"

# 4. Hygiene (CRITICAL)
export CARGO_TARGET_DIR="$REPO_ROOT/vivarium/benthic-0.1.0/target"

# 5. Build
echo "Incubating Benthic Specimen (Vanilla)..."
cd "$SPECIMEN_DIR"

# 6. Observation Mode: Catch build errors
# Using if ! command; then ... fi pattern to avoid set -e termination
if ! cargo build --release; then
    echo "Observation: Vanilla build failed (Deep Sea adaptation required)."
    exit 0
fi

echo "Observation: Incubation complete."
