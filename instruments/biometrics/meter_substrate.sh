#!/bin/bash
set -e

# meter_substrate.sh
# Usage: meter_substrate.sh <substrate_name>

if [ -z "$1" ]; then
    echo "Usage: $0 <substrate_name>"
    exit 1
fi

SUBSTRATE_NAME="$1"

# Resolve repo root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$REPO_ROOT/instruments/substrate/observatory_env.bash"
test -v VIVARIUM_DIR || { echo "Error: Environment not set"; exit 1; }

SUBSTRATE_BASE="$REPO_ROOT/vivarium/substrate"

TARGET_DIRS=()

if [ "$SUBSTRATE_NAME" == "rust" ]; then
    TARGET_DIRS+=("$SUBSTRATE_BASE/cargo")
    TARGET_DIRS+=("$SUBSTRATE_BASE/rustup")
elif [ "$SUBSTRATE_NAME" == "dotnet" ]; then
    TARGET_DIRS+=("$SUBSTRATE_BASE/dotnet-8.0")
else
    TARGET_DIRS+=("$SUBSTRATE_BASE/$SUBSTRATE_NAME")
fi

TOTAL_SIZE=0
TOTAL_FILES=0
FOUND_ANY=false

for dir in "${TARGET_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        FOUND_ANY=true
        # du -s returns size in blocks (1k usually).
        SIZE=$(du -s "$dir" | awk '{print $1}')
        FILES=$(find "$dir" -type f | wc -l)
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        TOTAL_FILES=$((TOTAL_FILES + FILES))
    fi
done

if [ "$FOUND_ANY" = false ]; then
    echo "Substrate '$SUBSTRATE_NAME' not found in $SUBSTRATE_BASE"
    echo "size_human: N/A"
    echo "file_count: 0"
    exit 0
fi

# Convert total size (kb) to human readable
# Simple approximation or use numfmt if available
# du -h doesn't take raw numbers.
# We can just output the total size in kb and let the caller handle format, or use du on all dirs at once.
# Let's use du -hc on all dirs

SIZE_HUMAN=$(du -hc "${TARGET_DIRS[@]}" 2>/dev/null | grep "total" | awk '{print $1}')

echo "Substrate: $SUBSTRATE_NAME"
echo "Size: $SIZE_HUMAN"
echo "Files: $TOTAL_FILES"
