#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
OBSERVATORY_ENV="$REPO_ROOT/instruments/substrate/observatory_env.bash"
ENSURE_DOTNET="$REPO_ROOT/instruments/substrate/ensure_dotnet.sh"

# Load Substrate Environment (Exports DOTNET_ROOT, PATH, etc.)
source "$OBSERVATORY_ENV"

# Verify/Install Dotnet (Idempotent)
"$ENSURE_DOTNET" > /dev/null

# Build Sequencer
echo "Building Sequencer..."
mkdir -p "$REPO_ROOT/vivarium/sequencer/obj/"
dotnet build "$SCRIPT_DIR/src/Sequencer.csproj" -c Release \
    --output "$REPO_ROOT/vivarium/sequencer/" \
    -p:BaseIntermediateOutputPath="$REPO_ROOT/vivarium/sequencer/obj/"

echo "Sequencer built successfully."
