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

# Argument Mapping
ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --user)
      ARGS+=("--first-name" "$2")
      shift; shift
      ;;
    --lastname)
      ARGS+=("--last-name" "$2")
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
      # Not yet implemented
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

"$BINARY" "${ARGS[@]}"
