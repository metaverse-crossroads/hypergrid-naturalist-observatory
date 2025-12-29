#!/usr/bin/env bash
set -e

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OBSERVATORY_ENV="$SCRIPT_DIR/observatory_env.bash"

# Source the Observatory Environment
if [ -f "$OBSERVATORY_ENV" ]; then
    source "$OBSERVATORY_ENV"
    test -v VIVARIUM_DIR || { echo "Error: Environment not set"; exit 1; }
else
    echo "Error: observatory_env.bash not found at $OBSERVATORY_ENV" >&2
    exit 1
fi

# Check if cargo exists and works
if [ -x "$CARGO_HOME/bin/cargo" ]; then
    echo "$CARGO_HOME"
    exit 0
fi

# Download and install rustup
echo "Observation: Rust missing. Acquiring Substrate..." >&2
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o "$SUBSTRATE_DIR/rustup-init.sh"
chmod +x "$SUBSTRATE_DIR/rustup-init.sh"

# Install Rust locally
# RUSTUP_HOME and CARGO_HOME are already exported by observatory_env.bash
"$SUBSTRATE_DIR/rustup-init.sh" -y --no-modify-path --profile minimal --default-toolchain stable >&2

# Clean up installer
rm "$SUBSTRATE_DIR/rustup-init.sh"

echo "$CARGO_HOME"
