#!/usr/bin/env bash
# species/libremetaverse/2.0.0.278/acquire.sh

set -e

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

# Source Observatory Environment
source "$REPO_ROOT/instruments/substrate/observatory_env.bash"
test -v VIVARIUM_DIR || { echo "Error: Environment not set"; exit 1; }

VIVARIUM_DIR="$REPO_ROOT/vivarium"
SPECIES="libremetaverse"
VERSION="2.0.0.278"
TARGET_DIR="$VIVARIUM_DIR/$SPECIES-$VERSION"
RECEIPTS_DIR="$TARGET_DIR/receipts"

# Configuration
REPO_URL="https://github.com/cinderblocks/libremetaverse.git"
COMMIT_HASH="2.0.0.278"

# Biometrics
STOPWATCH="$REPO_ROOT/instruments/biometrics/stopwatch.sh"

echo "[ACQUIRE] Species: $SPECIES ($VERSION)"

mkdir -p "$VIVARIUM_DIR"

# 1. Check for Limbo State (Directory exists but not a git repo)
if [ -d "$TARGET_DIR" ] && [ ! -d "$TARGET_DIR/.git" ]; then
    echo "WARNING: Directory $TARGET_DIR exists but is not a git repository (Limbo State)."
    if [ -s "$TARGET_DIR/acquired.txt" ]; then
        echo "         Auto-recovering by removing corrupted directory $TARGET_DIR..."
        rm -rf "$TARGET_DIR"
    else
        echo "         Examine/remove corrupted directory: $TARGET_DIR"
        exit 30
    fi
fi

if [ -d "$TARGET_DIR" ]; then
    echo "Directory $TARGET_DIR already exists."

    # Validate Remote
    CURRENT_URL=$(git -C "$TARGET_DIR" remote get-url origin 2>/dev/null || echo "none")
    if [[ "$CURRENT_URL" != *"$REPO_URL"* ]]; then
        echo "WARNING: Remote origin '$CURRENT_URL' does not match expected '$REPO_URL'."
        echo "Manual intervention required."
        exit 1
    fi

    # Check Status & Update
    echo "Fetching updates..."
    git -C "$TARGET_DIR" fetch --tags

    echo "Checking out $COMMIT_HASH..."
    # Attempt checkout. If it fails (due to dirty tree), recover.
    if ! git -C "$TARGET_DIR" checkout -f "$COMMIT_HASH"; then
        echo "WARNING: Failed to checkout $COMMIT_HASH (Dirty Tree?). Attempting reset..."
        # If hash is not a branch tip, reset hard to it might require finding it first,
        # but since we fetched, we should have it.
        # However, reset --hard to a hash works.
        git -C "$TARGET_DIR" reset --hard "$COMMIT_HASH"

        # Retry checkout to be sure we are detached at that commit
        if ! git -C "$TARGET_DIR" checkout -f "$COMMIT_HASH"; then
             echo "ERROR: Failed to checkout $COMMIT_HASH even after reset."
             exit 1
        fi
    fi

else
    echo "  Status: Absent (Cloning)"
    TEMP_RECEIPT="/tmp/clone_libremetaverse.json"

    # Clone
    "$STOPWATCH" "$TEMP_RECEIPT" git clone "$REPO_URL" "$TARGET_DIR"

    cd "$TARGET_DIR"
    git checkout "$COMMIT_HASH"

    mkdir -p "$RECEIPTS_DIR"
    if [ -f "$TEMP_RECEIPT" ]; then
        mv "$TEMP_RECEIPT" "$RECEIPTS_DIR/"
    fi

    echo "git clone \"$REPO_URL\" \"$TARGET_DIR\" && git checkout \"$COMMIT_HASH\"" > "$TARGET_DIR/acquired.txt"
fi

echo "[ACQUIRE] Complete."
