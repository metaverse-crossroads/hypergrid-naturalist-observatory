#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

# Source centralized environment
source "$REPO_ROOT/instruments/substrate/observatory_env.bash"

# Target Definition (VIVARIUM_DIR is exported by observatory_env)
SPECIMEN_DIR="$VIVARIUM_DIR/opensim-ngc-0.9.3"
ENSURE_DOTNET="$REPO_ROOT/instruments/substrate/ensure_dotnet.sh"

# Biometrics
STOPWATCH="$REPO_ROOT/instruments/biometrics/stopwatch.sh"
RECEIPTS_DIR="$SPECIMEN_DIR/receipts"
mkdir -p "$RECEIPTS_DIR"

# 1. Prerequisite Check
if [ ! -d "$SPECIMEN_DIR" ]; then
    echo "Specimen not found. Please run acquire.sh first."
    exit 1
fi

echo "Incubating OpenSim NGC..."

# 2. Load Substrate
# Verify/Install Dotnet (Idempotent)
"$ENSURE_DOTNET" > /dev/null

echo "Substrate active: $(dotnet --version)"

# 3. Patching Strategy: Idempotent & Robust
# Function to apply a patch only if not already applied, and fail if state is messy.
apply_patch_idempotent() {
    local patch_file="$1"
    local patch_name=$(basename "$patch_file")

    # Handle empty glob expansion
    if [ ! -f "$patch_file" ]; then
        return 0
    fi

    echo "Processing patch: $patch_file"

    # Check 1: Is it already applied? (Reverse dry-run)
    # If we can reverse it in dry-run, it means it is fully applied.
    if patch -p1 -R -s -f --dry-run < "$patch_file" > /dev/null 2>&1; then
        echo "  [OK] Patch already applied: $patch_name"
        return 0
    fi

    # Check 2: Is it cleanly applicable? (Forward dry-run)
    if patch -p1 -s -f --dry-run < "$patch_file" > /dev/null 2>&1; then
        echo "  [>>] Applying patch: $patch_name"
        if patch -p1 -s -f < "$patch_file"; then
             echo "  [OK] Successfully applied: $patch_name"
             return 0
        else
             echo "  [!!] Failed to apply patch: $patch_name (Unexpected error)"
             return 1
        fi
    fi

    # Fallback: State is indeterminate.
    echo "  [XX] CRITICAL: Patch state indeterminate for $patch_name"
    echo "       The patch is neither fully applied nor cleanly applicable."
    echo "       This indicates drift, manual modification, or a conflicting patch."
    return 1
}

cd "$SPECIMEN_DIR"

# Apply Fixes
for patch in "$SCRIPT_DIR/patches/fixes"/*.patch; do
    apply_patch_idempotent "$patch" || exit 1
done

# Apply Instrumentation
for patch in "$SCRIPT_DIR/patches/instrumentation"/*.patch; do
    apply_patch_idempotent "$patch" || exit 1
done

# 4. Build Solution
echo "Building Solution (Tranquillity.sln)..."
# dotnet build is incremental.
"$STOPWATCH" "$RECEIPTS_DIR/build_sln.json" dotnet build --configuration Release Tranquillity.sln

# 5. Populate Runtime Environment
# The build output (build/Release) lacks the configuration files and assets located in bin/
# because the .csproj only copies them on 'publish', not 'build'.
echo "Populating runtime environment..."
BUILD_DIR="$SPECIMEN_DIR/build/Release"
SOURCE_BIN="$SPECIMEN_DIR/bin"

if [ -d "$BUILD_DIR" ] && [ -d "$SOURCE_BIN" ]; then
    echo "Copying assets from $SOURCE_BIN to $BUILD_DIR..."
    cp -r "$SOURCE_BIN"/* "$BUILD_DIR/"
else
    echo "WARNING: Could not locate build output or source bin directory."
    echo "  Build Dir: $BUILD_DIR"
    echo "  Source Bin: $SOURCE_BIN"
    exit 1
fi

echo "Incubation complete."
