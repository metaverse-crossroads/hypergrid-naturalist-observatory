#!/usr/bin/env bash
set -e

# Resolve the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OBSERVATORY_ENV="$REPO_ROOT/instruments/substrate/observatory_env.bash"
ENSURE_RUST="$SCRIPT_DIR/ensure_rust.sh"

# 1. Load Substrate (Hardened)
if [ ! -f "$OBSERVATORY_ENV" ]; then
    echo "Error: observatory_env.bash not found at $OBSERVATORY_ENV" >&2
    exit 1
fi
source "$OBSERVATORY_ENV"

if [ ! -x "$ENSURE_RUST" ]; then
    echo "Error: ensure_rust.sh not found or not executable." >&2
    exit 1
fi

# CRITICAL: Use || exit 1 to catch failures in subshell
# ensure_rust is now idempotent and relies on env vars, but we still run it to verify
"$ENSURE_RUST" > /dev/null || exit 1

# 2. Setup Tracer
TRACER_DIR="$REPO_ROOT/vivarium/tracer"
# Ensure clean start
if [ -d "$TRACER_DIR" ]; then
    rm -rf "$TRACER_DIR"
fi
mkdir -p "$TRACER_DIR/src"

# 3. Hygiene Check
export CARGO_TARGET_DIR="$TRACER_DIR/target_waste"

# 4. The Payload
cat > "$TRACER_DIR/Cargo.toml" <<EOF
[package]
name = "tracer"
version = "0.1.0"
edition = "2021"

[dependencies]
log = "0.4"
EOF

cat > "$TRACER_DIR/src/main.rs" <<EOF
fn main() {
    println!("Tracer Impact Confirmed");
}
EOF

# 5. Fire
echo "Firing Tracer Bullet..."
cd "$TRACER_DIR"
cargo run

# 6. Verify
if [ ! -d "$CARGO_TARGET_DIR" ]; then
    echo "Observation: Hygiene Failure. CARGO_TARGET_DIR ($CARGO_TARGET_DIR) not created." >&2
    exit 1
fi

echo "Observation: Tracer Impact Confirmed. Hygiene Verified."

# 7. Cleanup
cd "$REPO_ROOT"
rm -rf "$TRACER_DIR"
