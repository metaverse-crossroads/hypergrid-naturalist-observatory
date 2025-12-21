#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
VIVARIUM_DIR="$REPO_ROOT/vivarium"
SPECIMEN_DIR="$VIVARIUM_DIR/opensim-core-0.9.3"
ENSURE_DOTNET="$REPO_ROOT/instruments/substrate/ensure_dotnet.sh"

# Biometrics
STOPWATCH="$REPO_ROOT/instruments/biometrics/stopwatch.sh"
RECEIPTS_DIR="$SPECIMEN_DIR/receipts"
mkdir -p "$RECEIPTS_DIR"

# 1. Prerequisite Check
if [ ! -d "$SPECIMEN_DIR" ]; then
    echo "Specimen not found. Please run acquire.sh first."
    exit 1
fi

echo "Incubating OpenSim Core..."

# 2. Load Substrate
DOTNET_ROOT=$("$ENSURE_DOTNET")

# 3. Activate
export DOTNET_ROOT
export PATH="$DOTNET_ROOT:$PATH"
echo "Substrate active: $(dotnet --version)"

# 4. Incubate
cd "$SPECIMEN_DIR"

# From runprebuild.sh logic
echo "Copying required dll..."
cp bin/System.Drawing.Common.dll.linux bin/System.Drawing.Common.dll

echo "Running Prebuild..."
"$STOPWATCH" "$RECEIPTS_DIR/prebuild.json" dotnet bin/prebuild.dll /target vs2022 /targetframework net8_0 /excludedir = "obj | bin" /file prebuild.xml

echo "Building Solution..."
"$STOPWATCH" "$RECEIPTS_DIR/build_sln.json" dotnet build --configuration Release OpenSim.sln

echo "Incubation complete."
