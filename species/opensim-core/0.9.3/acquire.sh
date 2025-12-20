#!/bin/bash
set -e

# Resolve the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Navigate to the repo root (assumed to be 3 levels up from species/opensim-core/0.9.3)
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
VIVARIUM_DIR="$REPO_ROOT/vivarium"

# Define target directory
TARGET_DIR="$VIVARIUM_DIR/opensim-core-0.9.3"
REPO_URL="https://github.com/opensim/opensim"
BRANCH="0.9.3.0"

echo "Acquiring OpenSim Core ${BRANCH}..."

# Ensure vivarium exists
mkdir -p "$VIVARIUM_DIR"

# Check if target directory exists
if [ -d "$TARGET_DIR" ]; then
    echo "Directory $TARGET_DIR already exists."

    # Check if it is a valid git repository
    if [ -d "$TARGET_DIR/.git" ]; then
        echo "Valid git repository detected."

        # Verify remote origin (loose check)
        CURRENT_URL=$(git -C "$TARGET_DIR" remote get-url origin)
        if [[ "$CURRENT_URL" != *"$REPO_URL"* ]]; then
            echo "WARNING: Remote origin $CURRENT_URL does not match expected $REPO_URL."
            echo "Please inspect $TARGET_DIR manually."
            exit 1
        fi

        # Check if we are on the right commit/branch (optional but good)
        echo "Updating/Verifying branch $BRANCH..."
        git -C "$TARGET_DIR" fetch origin
        git -C "$TARGET_DIR" checkout "$BRANCH"

    else
        echo "ERROR: Directory $TARGET_DIR exists but is not a git repository."
        echo "Aborting to avoid data loss."
        exit 1
    fi
else
    # Clone the repository
    echo "Cloning $REPO_URL into $TARGET_DIR..."
    git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$TARGET_DIR"
fi

echo "Acquisition complete: OpenSim Core $BRANCH"
