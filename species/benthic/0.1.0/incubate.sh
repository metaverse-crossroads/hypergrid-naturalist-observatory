#!/usr/bin/env bash
set -e

# Resolve the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SPECIMEN_DIR="$REPO_ROOT/vivarium/benthic-0.1.0/metaverse_client"
HEADLESS_CLIENT_SRC="$SCRIPT_DIR/headless_client.rs"

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

# 6. Grafting (Deep Sea Variant Adaptation)
echo "Grafting Headless Client..."

# 6a. Create Headless Client Crate
mkdir -p crates/headless_client/src
cat > crates/headless_client/Cargo.toml <<EOF
[package]
name = "headless_client"
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
if [ -f "$HEADLESS_CLIENT_SRC" ]; then
    cp "$HEADLESS_CLIENT_SRC" crates/headless_client/src/main.rs
else
    echo "Error: Source file $HEADLESS_CLIENT_SRC not found."
    exit 1
fi

# 6c. Register in Workspace (Idempotent)
if ! grep -q "crates/headless_client" Cargo.toml; then
    echo "Registering headless_client in workspace..."
    # We replace the closing bracket with our crate and the closing bracket
    # This assumes the members list ends with ']'
    if grep -q "members = \[" Cargo.toml; then
        # Check if it's single line or multi line
        # Simple hack: replace "crates/ui"," with "crates/ui", "crates/headless_client","
        # Or just find a known crate and append after it.
        # "crates/ui" seems standard.
        sed -i 's|"crates/ui"|"crates/ui", "crates/headless_client"|' Cargo.toml

        # Robustness Check
        if ! grep -q "crates/headless_client" Cargo.toml; then
            echo "Error: Failed to register headless_client in Cargo.toml via sed injection."
            echo "Please check Cargo.toml format."
            exit 1
        fi
        echo "Updated Cargo.toml"
    else
        echo "Warning: Could not parse Cargo.toml members."
        exit 1
    fi
else
    echo "Headless Client already registered in workspace."
fi

# 7. Incubation
echo "Incubating Deep Sea Variant..."
"$STOPWATCH" "$RECEIPTS_DIR/build_graft.json" cargo build --release --bin headless_client || exit 1

echo "Observation: Incubation complete."
