#!/usr/bin/env bash
set -e

# Resolve the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SPECIMEN_DIR="$REPO_ROOT/vivarium/benthic-0.1.0/metaverse_client"
DEEPSEA_CLIENT_SRC="$SCRIPT_DIR/deepsea_client.rs"
OBSERVATORY_ENV="$REPO_ROOT/instruments/substrate/observatory_env.bash"
ENSURE_RUST="$REPO_ROOT/instruments/substrate/ensure_rust.sh"

# 1. Prerequisite: Check if specimen exists
if [ ! -d "$SPECIMEN_DIR" ]; then
    echo "Observation: Specimen missing. Please run acquire.sh first."
    exit 1
fi

# Biometrics
STOPWATCH="$REPO_ROOT/instruments/biometrics/stopwatch.sh"
RECEIPTS_DIR="$REPO_ROOT/vivarium/benthic-0.1.0/receipts"
mkdir -p "$RECEIPTS_DIR"

# 2. Substrate: Call ensure_rust.sh
source "$OBSERVATORY_ENV"

if [ ! -x "$ENSURE_RUST" ]; then
    echo "Error: Substrate script not found or not executable at $ENSURE_RUST"
    exit 1
fi

# We don't need to capture output since observatory_env.bash sets vars
"$ENSURE_RUST" > /dev/null

# 3. Activate
# (Handled by observatory_env.bash)

# 4. Hygiene (CRITICAL)
export CARGO_TARGET_DIR="$REPO_ROOT/vivarium/benthic-0.1.0/target"

# --- INSERT START ---
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

    echo ""
    echo "       --- DEBUG REPORT ---"
    echo "       Patch File: $patch_file"
    echo "       Target Context: $SPECIMEN_DIR"

    echo ""
    echo "       Evidence (Dry-Run Attempts):"
    echo "       1. Reverse (Check if applied): patch -p1 -R -s -f --dry-run < $patch_name"
    if patch -p1 -R -s -f --dry-run < "$patch_file" 2>&1; then echo "          Result: SUCCESS (Should have returned 0 in script logic)"; else echo "          Result: FAILURE"; fi

    echo "       2. Forward (Check if applicable): patch -p1 -s -f --dry-run < $patch_name"
    if patch -p1 -s -f --dry-run < "$patch_file" 2>&1; then echo "          Result: SUCCESS"; else echo "          Result: FAILURE"; fi

    echo ""
    echo "       Target File Analysis:"
    # Extract target files from patch (lines starting with +++)
    # We use awk to be robust against path variations.
    grep "^+++ " "$patch_file" | while read -r line; do
        # Format usually: +++ b/OpenSim/Region/Application/OpenSim.cs
        # Remove "+++ "
        clean_line="${line#+++ }"
        # Remove prefix (b/ or a/) if present.
        # We assume standard git diff format.
        target_file=$(echo "$clean_line" | sed 's/^[ab]\///')

        if [ -f "$target_file" ]; then
            echo "       File: $target_file"
            ls -l "$target_file"

            echo "       Git Status (Local):"
            git status --short "$target_file"

            echo "       Git Diff (Laser-scoped):"
            # Show diff only for this file to reveal modifications
            git diff "$target_file"
        else
            echo "       File: $target_file (NOT FOUND)"
            echo "       Note: File might be new or path logic failed."
        fi
    done

    return 1
}

cd "$SPECIMEN_DIR"

# Apply Fixes
for patch in "$SCRIPT_DIR/patches/fixes"/*.patch; do
    apply_patch_idempotent "$patch"
done

# Apply Instrumentation
for patch in "$SCRIPT_DIR/patches/instrumentation"/*.patch; do
    apply_patch_idempotent "$patch"
done
# --- INSERT END ---

# 5. Hydration (Atomic)
echo "Hydrating..."
"$STOPWATCH" "$RECEIPTS_DIR/hydration.json" cargo fetch || exit 1

# 6. Grafting (Deep Sea Variant Adaptation)
echo "Grafting Deep Sea Client..."

# 6a. Create Deep Sea Client Crate
mkdir -p crates/deepsea_client/src
cat > crates/deepsea_client/Cargo.toml <<EOF
[package]
name = "deepsea_client"
version = "0.1.0"
edition = "2021"

[dependencies]
metaverse_core = { path = "../core" }
metaverse_messages = { path = "../messages" }
actix = "0.13"
tokio = { version = "1", features = ["full"] }
log = "0.4"
env_logger = "0.11"
clap = { version = "4.5", features = ["derive"] }
anyhow = "1.0"
crossbeam-channel = "0.5"
tempfile = "3.10"
uuid = "1.0"
chrono = "0.4"
EOF

# 6b. Inject Source Code
if [ -f "$DEEPSEA_CLIENT_SRC" ]; then
    cp "$DEEPSEA_CLIENT_SRC" crates/deepsea_client/src/main.rs
else
    echo "Error: Source file $DEEPSEA_CLIENT_SRC not found."
    exit 1
fi

# 6c. Register in Workspace (Idempotent)
if ! grep -q "crates/deepsea_client" Cargo.toml; then
    echo "Registering deepsea_client in workspace..."
    # We replace the closing bracket with our crate and the closing bracket
    # This assumes the members list ends with ']'
    if grep -q "members = \[" Cargo.toml; then
        # Check if it's single line or multi line
        # Simple hack: replace "crates/ui"," with "crates/ui", "crates/deepsea_client","
        # Or just find a known crate and append after it.
        # "crates/ui" seems standard.
        sed -i 's|"crates/ui"|"crates/ui", "crates/deepsea_client"|' Cargo.toml

        # Robustness Check
        if ! grep -q "crates/deepsea_client" Cargo.toml; then
            echo "Error: Failed to register deepsea_client in Cargo.toml via sed injection."
            echo "Please check Cargo.toml format."
            exit 1
        fi
        echo "Updated Cargo.toml"
    else
        echo "Warning: Could not parse Cargo.toml members."
        exit 1
    fi
else
    echo "Deep Sea Client already registered in workspace."
fi

# 7. Incubation
echo "Incubating Deep Sea Variant..."
# Force rebuild of deepsea_client to ensure changes are picked up
touch crates/deepsea_client/src/main.rs
"$STOPWATCH" "$RECEIPTS_DIR/build_graft.json" cargo build --release --bin deepsea_client || exit 1

echo "Observation: Incubation complete."
