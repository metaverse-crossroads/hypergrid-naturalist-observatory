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
