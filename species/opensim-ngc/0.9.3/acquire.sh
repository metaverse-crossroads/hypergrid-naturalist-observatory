#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

# Source centralized environment
source "$REPO_ROOT/instruments/substrate/observatory_env.bash"
test -v VIVARIUM_DIR || { echo "Error: Environment not set"; exit 1; }

# Target Definition (VIVARIUM_DIR is exported by observatory_env)
TARGET_DIR="$VIVARIUM_DIR/opensim-ngc-0.9.3"
RECEIPTS_DIR="$TARGET_DIR/receipts"

# Configuration
REPO_URL="https://github.com/OpenSim-NGC/OpenSim-Tranquillity"
BRANCH="tranquillity-0.9.3.9441"

# Biometrics
STOPWATCH="$REPO_ROOT/instruments/biometrics/stopwatch.sh"

echo "Acquiring OpenSim NGC ${BRANCH}..."

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
    git -C "$TARGET_DIR" fetch origin

    echo "Checking out $BRANCH..."
    # Attempt checkout. If it fails (due to dirty tree), recover.
    if ! git -C "$TARGET_DIR" checkout "$BRANCH"; then
        echo "WARNING: Failed to checkout $BRANCH (Dirty Tree?). Attempting reset..."
        git -C "$TARGET_DIR" reset --hard origin/"$BRANCH"

        # Retry checkout
        if ! git -C "$TARGET_DIR" checkout "$BRANCH"; then
             echo "ERROR: Failed to checkout $BRANCH even after reset."
             exit 1
        fi
    fi

else
    echo "Cloning $REPO_URL into $TARGET_DIR..."
    TEMP_RECEIPT="/tmp/clone_opensim.json"

    # Clone
    "$STOPWATCH" "$TEMP_RECEIPT" git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$TARGET_DIR"

    mkdir -p "$RECEIPTS_DIR"
    if [ -f "$TEMP_RECEIPT" ]; then
        mv "$TEMP_RECEIPT" "$RECEIPTS_DIR/"
    fi

    echo "git clone --branch \"$BRANCH\" --depth 1 \"$REPO_URL\" \"$TARGET_DIR\"" > "$TARGET_DIR/acquired.txt"
fi

echo "Acquisition complete: OpenSim NGC $BRANCH"
