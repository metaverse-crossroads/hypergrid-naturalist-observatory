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

# Default values
firstname=""
lastname=""
password=""
uri=""
help=false
version=false

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --firstname|-f) firstname="$2"; shift ;;
        --lastname|-l) lastname="$2"; shift ;;
        --password|-p) password="$2"; shift ;;
        --uri|-u|-s) uri="$2"; shift ;;
        --help|-h) help=true ;;
        --version|-v) version=true ;;
        --user) firstname="$2"; shift ;; # legacy
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [ "$help" = true ]; then
    exec "$BINARY" --help
    exit 0
fi

if [ "$version" = true ]; then
    exec "$BINARY" --version
    exit 0
fi

# Construct command
CMD=("$BINARY")

if [ -n "$firstname" ]; then CMD+=("--firstname" "$firstname"); fi
if [ -n "$lastname" ]; then CMD+=("--lastname" "$lastname"); fi
if [ -n "$password" ]; then CMD+=("--password" "$password"); fi
if [ -n "$uri" ]; then CMD+=("--uri" "$uri"); fi

# Execute
exec "${CMD[@]}"
