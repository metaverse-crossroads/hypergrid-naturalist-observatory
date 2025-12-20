#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
ENSURE_DOTNET="$REPO_ROOT/instruments/substrate/ensure_dotnet.sh"

# Load Substrate
DOTNET_ROOT=$("$ENSURE_DOTNET")
export DOTNET_ROOT
export PATH="$DOTNET_ROOT:$PATH"
echo "Substrate active: $(dotnet --version)"

# Build the Mimic instrument
echo "Building Mimic..."
# Must run from instrument root or point to csproj
cd "$SCRIPT_DIR"
dotnet build src/Mimic.csproj
