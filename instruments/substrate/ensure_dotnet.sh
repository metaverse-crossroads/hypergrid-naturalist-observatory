#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OBSERVATORY_ENV="$SCRIPT_DIR/observatory_env.bash"

# Source the Observatory Environment
if [ -f "$OBSERVATORY_ENV" ]; then
    source "$OBSERVATORY_ENV"
else
    echo "Error: observatory_env.bash not found at $OBSERVATORY_ENV" >&2
    exit 1
fi

# Default version (used for download URL)
TARGET_VERSION="${1:-8.0}"

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
