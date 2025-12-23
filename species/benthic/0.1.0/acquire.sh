#!/bin/bash
set -e

# Resolve the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Navigate to the repo root (assumed to be 3 levels up from species/benthic/0.1.0)
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
VIVARIUM_DIR="$REPO_ROOT/vivarium"

# Define target directory root
TARGET_ROOT="$VIVARIUM_DIR/benthic-0.1.0"

# Repositories
# Using GitHub URLs as per DIRECT_PATH.md
CLIENT_REPO="https://github.com/benthic-mmo/metaverse_client"
MESH_REPO="https://github.com/benthic-mmo/metaverse_mesh"
SERDE_REPO="https://github.com/benthic-mmo/serde-llsd"

# Biometrics
STOPWATCH="$REPO_ROOT/instruments/biometrics/stopwatch.sh"
RECEIPTS_DIR="$TARGET_ROOT/receipts"
mkdir -p "$RECEIPTS_DIR"

echo "Acquiring Benthic Specimen (0.1.0)..."

# Ensure vivarium exists
mkdir -p "$TARGET_ROOT"

# Function to clone or verify repo
acquire_repo() {
    local repo_url=$1
    local dir_name=$2
    local target_path="$TARGET_ROOT/$dir_name"

    if [ -d "$target_path" ]; then
        echo "Directory $target_path already exists."
        if [ -d "$target_path/.git" ]; then
            echo "Valid git repository detected at $dir_name."
            # Basic origin check
            local current_url=$(git -C "$target_path" remote get-url origin)
            if [[ "$current_url" != *"$repo_url"* ]]; then
                 echo "WARNING: Remote origin for $dir_name does not match. Expected $repo_url, got $current_url."
                 # Clean Room Protocol: Fail if origin mismatch
                 exit 1
            fi
            
            # Clean Room Protocol: Check for dirty state
            if [[ -n $(git -C "$target_path" status --porcelain) ]]; then
                echo "WARNING: Repository $dir_name is dirty. Clean Room Protocol requires a clean state."
                echo "Run 'rm -rf $target_path' to restart."
                exit 1
            fi
        else
             echo "ERROR: $target_path exists but is not a git repo."
             exit 1
        fi
    else
        echo "Cloning $repo_url into $target_path..."
        # Stopwatch handles the timing and receipt generation
        "$STOPWATCH" "$RECEIPTS_DIR/clone_$dir_name.json" git clone "$repo_url" "$target_path"
    fi
}

acquire_repo "$CLIENT_REPO" "metaverse_client"
acquire_repo "$MESH_REPO" "metaverse_mesh"
# Rename target for serde-llsd to benthic-serde-llsd as required by build
acquire_repo "$SERDE_REPO" "benthic-serde-llsd"

echo "Acquisition complete: Benthic 0.1.0 Specimen"
