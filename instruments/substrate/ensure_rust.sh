#!/usr/bin/env bash
set -e

# Resolve the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VIVARIUM_DIR="$REPO_ROOT/vivarium"
SUBSTRATE_DIR="$VIVARIUM_DIR/substrate"
CARGO_HOME="$SUBSTRATE_DIR/cargo"
RUSTUP_HOME="$SUBSTRATE_DIR/rustup"

# Check if cargo exists and works
if [ -x "$CARGO_HOME/bin/cargo" ]; then
    echo "$CARGO_HOME"
    exit 0
fi

# Ensure substrate directory exists
mkdir -p "$SUBSTRATE_DIR"

# Download and install rustup
echo "Observation: Rust missing. Acquiring Substrate..." >&2
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o "$SUBSTRATE_DIR/rustup-init.sh"
chmod +x "$SUBSTRATE_DIR/rustup-init.sh"

# Install Rust locally
# We must export these before running rustup-init so it knows where to install
export RUSTUP_HOME="$RUSTUP_HOME"
export CARGO_HOME="$CARGO_HOME"

"$SUBSTRATE_DIR/rustup-init.sh" -y --no-modify-path --profile minimal --default-toolchain stable >&2

# Clean up installer
rm "$SUBSTRATE_DIR/rustup-init.sh"

echo "$CARGO_HOME"
