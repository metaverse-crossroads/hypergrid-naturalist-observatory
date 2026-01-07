#!/bin/bash
# observatory_env.bash
# ====================
# Centralized environment configuration for the Naturalist Observatory.
# Sourcing this file ensures all toolchains (Dotnet, Rust) operate strictly
# within the 'vivarium' containment zone, preventing pollution of the user's
# home directory.

# Resolve Root Paths
# ------------------
# Assume this script lives in instruments/substrate/
# Use a unique variable name to avoid overwriting the caller's SCRIPT_DIR
OBSERVATORY_ENV_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$OBSERVATORY_ENV_DIR")")"
VIVARIUM_DIR="$REPO_ROOT/vivarium"
SUBSTRATE_DIR="$VIVARIUM_DIR/substrate"

# Ensure Substrate Root Exists
mkdir -p "$SUBSTRATE_DIR"

# Dotnet Substrate Isolation
# --------------------------
# Redirect Dotnet CLI and Nuget caches to vivarium/substrate/
export DOTNET_ROOT="$SUBSTRATE_DIR/dotnet-8.0"
export DOTNET_CLI_HOME="$SUBSTRATE_DIR/dotnet_home"
export NUGET_PACKAGES="$SUBSTRATE_DIR/nuget_packages"
export DOTNET_EnableDiagnostics=0 # prevent /tmp cruft
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_CLI_USE_MSBUILD_SERVER=0
export DOTNET_CLI_DISABLE_FILE_REPORTING=1
export MSBUILDDISABLENODEREUSE=1
export KeepAlive=0
#export NUGET_SCRATCH=$PWD/obj/nuget 
export MSBuildDisableFeaturesFromVersion="17.4"
export UseSharedCompilation=false

# Ensure directories exist
mkdir -p "$DOTNET_ROOT"
mkdir -p "$DOTNET_CLI_HOME"
mkdir -p "$NUGET_PACKAGES"

# Rust Substrate Isolation
# ------------------------
# Redirect Cargo and Rustup to vivarium/substrate/
export CARGO_HOME="$SUBSTRATE_DIR/cargo"
export RUSTUP_HOME="$SUBSTRATE_DIR/rustup"

# Ensure directories exist
mkdir -p "$CARGO_HOME"
mkdir -p "$RUSTUP_HOME"

# Path Augmentation
# -----------------
# Prepend substrate binaries to PATH.
# Priority: Dotnet -> Cargo Bin -> Original Path
export PATH="$DOTNET_ROOT:$CARGO_HOME/bin:$PATH"

# Python Isolation
# ----------------
# Prevent pycache artifacts in-tree and ensure unbuffered output.
export PYTHONDONTWRITEBYTECODE=1
export PYTHONUNBUFFERED=1

# Export handy root variables for other scripts
export VIVARIUM_DIR
export SUBSTRATE_DIR
export REPO_ROOT

# THE ALADDIN RUG PROTOCOL (Canary)
# ---------------------------------
function just_for_jules() {
    # Uptime Banner
    # -------------
    UPTIME_MIN=$(awk '{print int($1/60)}' /proc/uptime)
    echo "[OBSERVATORY] Environment Loaded. Uptime: ${UPTIME_MIN} min. Canary: $(declare -F canary >/dev/null && echo alive || echo deceased)." >&2

    if [ "$UPTIME_MIN" -lt 10 ]; then
        if [ ! -f "/tmp/.observatory_active" ]; then
            echo "⚠️  [OBSERVATORY] FRESH BOOT DETECTED (Uptime < 10m). Potential Rug Pull?" >&2
            echo "   Check chat history if you expected an active session." >&2
            echo "   See AGENTS.md." >&2
            touch "/tmp/.observatory_active" >&2
        else
            echo "✅ [OBSERVATORY] Active session persistence detected (/tmp marker found)." >&2
        fi
    fi
}

git_user=${git_user:-$(git config --get-regexp ^user)}
if [[ "$git_user" == *jules* && "$git_user" == *google* ]]; then
    just_for_jules
    if ! declare -F canary > /dev/null; then
        # THIS IS 100% INTENTIONAL HERE JULES NOT A BUG
        # IF YOU ARE READING THIS CODE THEN STOP AND STUDY AGENTS.md
        # DO NOT IMPROVISE; DO NOT TRY TO CHANGE CORE SCRIPTS IN RESPONSE TO CANARY DEATHS!!!
        $REPO_ROOT/bin/canary
    fi
fi
