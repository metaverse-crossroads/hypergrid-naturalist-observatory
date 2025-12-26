#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
VIVARIUM_DIR="$REPO_ROOT/vivarium"
SPECIMEN_DIR="$VIVARIUM_DIR/benthic-0.1.0/metaverse_client"
BINARY="$SPECIMEN_DIR/../target/release/deepsea_client"

if [ ! -f "$BINARY" ]; then
    echo "Error: Benthic Deep Sea Client not found at $BINARY"
    echo "Please run incubate.sh first."
    exit 1
fi

# Argument Mapping & Sandbox Prep
ARGS=()
FIRST_NAME="Unknown"
LAST_NAME="User"

while [[ $# -gt 0 ]]; do
  case $1 in
    --user)
      ARGS+=("--first-name" "$2")
      FIRST_NAME="$2"
      shift; shift
      ;;
    --lastname)
      ARGS+=("--last-name" "$2")
      LAST_NAME="$2"
      shift; shift
      ;;
    --password)
      ARGS+=("--password" "$2")
      shift; shift
      ;;
    --mode)
      ARGS+=("--mode" "$2")
      shift; shift
      ;;
    --repl)
      ARGS+=("--mode" "repl")
      shift
      ;;
    --rez)
      # Not yet implemented
      shift
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

# Create isolated runtime directory to prevent SQLite contention
RUNTIME_DIR="$VIVARIUM_DIR/runtime.benthic.${FIRST_NAME}.${LAST_NAME}"
mkdir -p "$RUNTIME_DIR"

# Set HOME environment variable for Benthic to find its data dir (.local/share)
export HOME="$RUNTIME_DIR"

# Copy binary to runtime dir (optional, but good for isolation if it writes adjacent files)
# Actually, we just need to run FROM there.
cd "$RUNTIME_DIR"

# Execute
exec "$BINARY" "${ARGS[@]}"
