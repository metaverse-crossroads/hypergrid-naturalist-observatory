#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
VIVARIUM_DIR="$REPO_ROOT/vivarium"
TARGET_DIR="$VIVARIUM_DIR/opensim-core-0.9.3"
RECEIPTS_DIR="$TARGET_DIR/receipts"

# Configuration
REPO_URL="https://github.com/opensim/opensim"
BRANCH="0.9.3.0"

# Biometrics
STOPWATCH="$REPO_ROOT/instruments/biometrics/stopwatch.sh"

echo "Acquiring OpenSim Core ${BRANCH}..."

mkdir -p "$VIVARIUM_DIR"

if [ -d "$TARGET_DIR" ]; then
    echo "Directory $TARGET_DIR already exists."

    # Validate Git Repo
    if [ ! -d "$TARGET_DIR/.git" ]; then
        echo "ERROR: Directory $TARGET_DIR exists but is not a git repository."
        echo "       This usually implies a corrupted or manually created directory."
        echo ""
        echo "Contents of target directory (top 20):"
        ls -laF "$TARGET_DIR" | head -n 20
        echo ""
        echo "SUGGESTION: Remove the directory and re-run this script to acquire a fresh copy."
        echo "  rm -rf \"$TARGET_DIR\""
        echo "  $0"
        exit 1
    fi

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
    # Attempt checkout. If it fails (due to dirty tree), we capture the error.
    if ! git -C "$TARGET_DIR" checkout "$BRANCH"; then
        echo "ERROR: Failed to checkout $BRANCH."
        echo "This usually means you have local changes (patches?) that conflict with the checkout."
        echo "To reset (DESTROYING LOCAL CHANGES), run: git -C $TARGET_DIR reset --hard origin/$BRANCH"
        exit 1
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
fi

echo "Acquisition complete: OpenSim Core $BRANCH"
