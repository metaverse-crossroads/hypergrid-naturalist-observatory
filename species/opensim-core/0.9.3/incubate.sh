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
DOTNET_ROOT=$("$ENSURE_DOTNET") || exit 1

# 3. Activate
export DOTNET_ROOT
export PATH="$DOTNET_ROOT:$PATH"
echo "Substrate active: $(dotnet --version)"

# 4. Incubate
cd "$SPECIMEN_DIR"

# Apply Patches (Granular Strategy)
echo "Applying Patches..."
if [ ! -f "patches_applied.marker" ]; then
    # Fixes
    for patch in "$SCRIPT_DIR/patches/fixes"/*.patch; do
        if [ -f "$patch" ]; then
            echo "Applying fix: $(basename "$patch")..."
            patch -p1 < "$patch"
        fi
    done

    # Instrumentation
    for patch in "$SCRIPT_DIR/patches/instrumentation"/*.patch; do
        if [ -f "$patch" ]; then
            echo "Applying instrumentation: $(basename "$patch")..."
            patch -p1 < "$patch"
        fi
    done

    touch "patches_applied.marker"
else
    echo "Patches already applied (marker found)."
fi

# Ensure bin exists
mkdir -p bin

# Bootstrap Prebuild if missing (Resilience Strategy)
if [ ! -f "bin/prebuild.dll" ]; then
    echo "Bootstrapping Prebuild..."
    dotnet build Prebuild/src/Prebuild.Bootstrap.csproj -c Release

    # Locate and copy
    built_dll=$(find Prebuild/src/bin/Release/net8.0 -name "prebuild.dll" | head -n 1)
    if [ -n "$built_dll" ]; then
        cp "$built_dll" bin/
        cp "${built_dll%.*}.runtimeconfig.json" bin/ 2>/dev/null || true
    else
        echo "Failed to locate built prebuild.dll"
    fi
fi

if [ ! -f "bin/prebuild.dll" ]; then
    echo "Error: bin/prebuild.dll not found even after bootstrap attempt."
    exit 1
fi

# From runprebuild.sh logic
echo "Copying required dll..."
if [ -f "bin/System.Drawing.Common.dll.linux" ]; then
    cp bin/System.Drawing.Common.dll.linux bin/System.Drawing.Common.dll
fi

echo "Running Prebuild..."
"$STOPWATCH" "$RECEIPTS_DIR/prebuild.json" dotnet bin/prebuild.dll /target vs2022 /targetframework net8_0 /excludedir = "obj | bin" /file prebuild.xml

echo "Building Solution..."
"$STOPWATCH" "$RECEIPTS_DIR/build_sln.json" dotnet build --configuration Release OpenSim.sln

echo "Incubation complete."
