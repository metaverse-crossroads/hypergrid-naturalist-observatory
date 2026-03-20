#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OBSERVATORY_ENV="$SCRIPT_DIR/observatory_env.bash"

# Source the Observatory Environment
if [ -f "$OBSERVATORY_ENV" ]; then
    source "$OBSERVATORY_ENV"
    [[ -v VIVARIUM_DIR ]] || { echo "Error: Environment not set"; exit 1; }
else
    echo "Error: observatory_env.bash not found at $OBSERVATORY_ENV" >&2
    exit 1
fi

# --- OS Logic Prelude ---
case "$OSTYPE" in
  linux*)   OS="linux"; EXT="tar.gz" ;;
  darwin*)  OS="macos"; EXT="tar.gz" ;;
  msys*)    OS="win";   EXT="zip"    ;; # Git Bash
  *)        echo "Unsupported OS: $OSTYPE" >&2; exit 1 ;;
esac

TARGET_VERSION="${1:-8.0}"
DOTNET_EXE="$DOTNET_ROOT/dotnet"
[[ "$OS" == "win" ]] && DOTNET_EXE="$DOTNET_ROOT/dotnet.exe"

# Check if viable
if [[ -x "$DOTNET_EXE" ]]; then
    if "$DOTNET_EXE" --version > /dev/null 2>&1; then
        echo "$DOTNET_ROOT"
        exit 0
    fi
fi

# Handle Symlink Guard
if [[ -L "$DOTNET_ROOT" ]]; then
    echo "DOTNET_ROOT is a symlink. Handle manual config (e.g. mklink)." >&2
    exit 29
fi

echo "Provisioning .NET $TARGET_VERSION ($OS)..." >&2

# Clean and Prep
rm -rf "$DOTNET_ROOT"
mkdir -p "$DOTNET_ROOT"

# Construct URL (Using aka.ms mapping)
# [HTTPS][AKA][MS]/dotnet/$TARGET_VERSION/dotnet-sdk-$OS-x64.$EXT
URL="https://aka.ms/dotnet/$TARGET_VERSION/dotnet-sdk-$OS-x64.$EXT"
ARCHIVE="$SUBSTRATE_DIR/dotnet-sdk-$OS-x64.$EXT"

echo "Downloading from $URL..." >&2
curl -sSL -o "$ARCHIVE" "$URL"

echo "Extracting..." >&2
if [[ "$EXT" == "zip" ]]; then
    unzip -q "$ARCHIVE" -d "$DOTNET_ROOT"
else
    tar -xzf "$ARCHIVE" -C "$DOTNET_ROOT"
fi

rm "$ARCHIVE"

# Final Verification
if "$DOTNET_EXE" --version > /dev/null 2>&1; then
    echo "$DOTNET_ROOT"
else
    echo "Error: Failed to verify dotnet installation at $DOTNET_EXE" >&2
    exit 1
fi
