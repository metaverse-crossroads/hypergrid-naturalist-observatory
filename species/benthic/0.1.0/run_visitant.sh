#!/bin/bash
set -e

# Wrapper script to run the Benthic Visitant (Rust)
# Maps standard Visitant arguments to the rust binary arguments.

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
VIVARIUM_DIR="$REPO_ROOT/vivarium"
BENTHIC_DIR="$VIVARIUM_DIR/benthic-0.1.0"
BINARY="$BENTHIC_DIR/target/release/deepsea_client"

# Check if binary exists
if [ ! -f "$BINARY" ]; then
    echo "Error: Benthic binary not found at $BINARY"
    echo "Please run incubate.sh first."
    exit 1
fi

# Pass all arguments directly to the binary
exec "$BINARY" "$@"
