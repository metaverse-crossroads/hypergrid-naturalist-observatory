#!/usr/bin/env bash
# species/libremetaverse/2.0.0.278/acquire.sh

set -e

SPECIES="libremetaverse"
VERSION="2.0.0.278"
REPO_URL="https://github.com/cinderblocks/libremetaverse.git"
COMMIT_HASH="2.0.0.278"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
VIVARIUM_DIR="$REPO_ROOT/vivarium/$SPECIES-$VERSION"

echo "[ACQUIRE] Species: $SPECIES ($VERSION)"

if [ -d "$VIVARIUM_DIR" ]; then
    if [ -d "$VIVARIUM_DIR/.git" ]; then
         echo "  Status: Resident (Updating)"
         cd "$VIVARIUM_DIR"
         git fetch --tags
         git checkout -f "$COMMIT_HASH"
    else
        echo "  Status: Limbo (Resetting)"
        rm -rf "$VIVARIUM_DIR"
        git clone "$REPO_URL" "$VIVARIUM_DIR"
        cd "$VIVARIUM_DIR"
        git checkout "$COMMIT_HASH"
    fi
else
    echo "  Status: Absent (Cloning)"
    git clone "$REPO_URL" "$VIVARIUM_DIR"
    cd "$VIVARIUM_DIR"
    git checkout "$COMMIT_HASH"
fi

echo "[ACQUIRE] Complete."
