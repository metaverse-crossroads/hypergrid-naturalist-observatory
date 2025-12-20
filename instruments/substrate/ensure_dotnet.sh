#!/bin/bash
set -e

# Default version
TARGET_VERSION="${1:-8.0}"

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
VIVARIUM_DIR="$REPO_ROOT/vivarium"
SUBSTRATE_DIR="$VIVARIUM_DIR/substrate"
DOTNET_ROOT="$SUBSTRATE_DIR/dotnet-$TARGET_VERSION"

# Ensure substrate dir exists
mkdir -p "$SUBSTRATE_DIR"

# Check if viable
if [ -x "$DOTNET_ROOT/dotnet" ]; then
    if "$DOTNET_ROOT/dotnet" --version > /dev/null 2>&1; then
        # It works.
        echo "$DOTNET_ROOT"
        exit 0
    fi
fi

echo "Initializing Substrate (dotnet $TARGET_VERSION)..." >&2

# Clean up any partial install
rm -rf "$DOTNET_ROOT"
mkdir -p "$DOTNET_ROOT"

# Download
TARBALL="$SUBSTRATE_DIR/dotnet-sdk-linux-x64.tar.gz"
URL="https://aka.ms/dotnet/$TARGET_VERSION/dotnet-sdk-linux-x64.tar.gz"

echo "Downloading from $URL..." >&2
# Use wget to download to stdout and pipe to tar to avoid intermediate file if possible,
# but keeping the tarball is safer for retries or debugging.
# We will download to file as per plan.
wget -q -O "$TARBALL" "$URL"

echo "Extracting..." >&2
tar -xzf "$TARBALL" -C "$DOTNET_ROOT"

# Cleanup tarball
rm "$TARBALL"

# Verify
if "$DOTNET_ROOT/dotnet" --version > /dev/null 2>&1; then
    echo "$DOTNET_ROOT"
else
    echo "Error: Failed to verify dotnet installation." >&2
    exit 1
fi
