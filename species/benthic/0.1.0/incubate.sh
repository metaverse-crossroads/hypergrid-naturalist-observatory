#!/usr/bin/env bash
set -e

# Resolve the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SPECIMEN_DIR="$REPO_ROOT/vivarium/benthic-0.1.0/metaverse_client"
PATCH_PATH="$SCRIPT_DIR/adapt_deepsea.patch"

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
ENSURE_RUST="$REPO_ROOT/instruments/substrate/ensure_rust.sh"
if [ ! -x "$ENSURE_RUST" ]; then
    echo "Error: Substrate script not found or not executable at $ENSURE_RUST"
    exit 1
fi

# Capture the output of ensure_rust.sh (which is CARGO_HOME)
# CRITICAL: Use || exit 1 to catch failures in subshell
CARGO_HOME_PATH=$("$ENSURE_RUST") || exit 1

# 3. Activate
export CARGO_HOME="$CARGO_HOME_PATH"
export PATH="$CARGO_HOME/bin:$PATH"

# 4. Hygiene (CRITICAL)
export CARGO_TARGET_DIR="$REPO_ROOT/vivarium/benthic-0.1.0/target"

cd "$SPECIMEN_DIR"

# 5. Hydration (Atomic)
echo "Hydrating..."
"$STOPWATCH" "$RECEIPTS_DIR/hydration.json" cargo fetch || exit 1

# 6. Diagnostic Check (The Upstream Organs)
echo "Diagnosing Upstream Vital Organs..."
# We wrap the combined check or separate them? Let's wrap them individually for better granularity, or as a block?
# The prompt implies wrapping heavy operations.
# Let's wrap the first check.
if ! "$STOPWATCH" "$RECEIPTS_DIR/build_upstream.json" cargo build --release -p metaverse_core -p metaverse_messages; then
    echo "DIAGNOSIS: Upstream Benthic is rotten."
    exit 1
fi

# 7. Mutation (Idempotent)
if [ ! -f "crates/headless_client/Cargo.toml" ]; then
    echo "Applying Deep Sea adaptation..."
    # Patch is corrupt (missing space in context lines starting with tab), fix on fly
    sed 's/^\t/ \t/' "$PATCH_PATH" | git apply || exit 1
else
    echo "Deep Sea adaptation already present."
fi

# 8. Surgical Incubation (The Graft)
echo "Incubating Deep Sea Variant..."
if ! "$STOPWATCH" "$RECEIPTS_DIR/build_graft.json" cargo build --release -p headless_client; then
    echo "DIAGNOSIS: Deep Sea Graft failed (Check patch compatibility)."
    exit 1
fi

echo "Observation: Incubation complete."
