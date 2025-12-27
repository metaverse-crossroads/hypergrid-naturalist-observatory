#!/bin/bash
# species/libremetaverse/2.0.0.278/incubate.sh
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
VIVARIUM_DIR="$REPO_ROOT/vivarium"
SPECIMEN_DIR="$VIVARIUM_DIR/libremetaverse-2.0.0.278"
ENSURE_DOTNET="$REPO_ROOT/instruments/substrate/ensure_dotnet.sh"

# 1. Prerequisite Check
if [ ! -d "$SPECIMEN_DIR" ]; then
    echo "Specimen not found. Please run acquire.sh first."
    exit 1
fi

echo "Incubating LibreMetaverse (2.0.0.278)..."

# 2. Load Substrate
DOTNET_ROOT=$("$ENSURE_DOTNET") || exit 1
export DOTNET_ROOT
export PATH="$DOTNET_ROOT:$PATH"
echo "Substrate active: $(dotnet --version)"

cd "$SPECIMEN_DIR"

# 3. Preparation: Remove Windows-only projects
echo "Preparing solution structure..."
if [ -f "LibreMetaverse.GUI/LibreMetaverse.GUI.csproj" ]; then
    dotnet sln LibreMetaverse.sln remove LibreMetaverse.GUI/LibreMetaverse.GUI.csproj || true
    rm LibreMetaverse.GUI/LibreMetaverse.GUI.csproj
fi

if [ -f "Programs/Baker/Baker.csproj" ]; then
    dotnet sln LibreMetaverse.sln remove Programs/Baker/Baker.csproj || true
    rm Programs/Baker/Baker.csproj
fi

# 4. Preparation: Retarget to .NET 8
echo "Retargeting to .NET 8..."
grep -r "net5.0" . | cut -d: -f1 | sort | uniq | xargs sed -i 's/net5.0/net8.0/g' || true
grep -r "net50" . | cut -d: -f1 | sort | uniq | xargs sed -i 's/net50/net8.0/g' || true
grep -r "netcoreapp3.1" . | cut -d: -f1 | sort | uniq | xargs sed -i 's/netcoreapp3.1/net8.0/g' || true

# 5. Build LibreMetaverse
echo "Building LibreMetaverse..."
dotnet restore LibreMetaverse.sln
dotnet build LibreMetaverse.sln -c Release

# 6. Build DeepSeaClient
echo "Building DeepSeaClient..."
SRC_DIR="$SCRIPT_DIR/src"
TARGET_DIR="$SPECIMEN_DIR/src"

mkdir -p "$TARGET_DIR"
cp "$SRC_DIR/DeepSeaClient.cs" "$TARGET_DIR/"
cp "$SRC_DIR/DeepSeaClient.csproj" "$TARGET_DIR/"

# Create obj decoy file to prevent auto-staging from polluting the repo
# We must use a BaseIntermediateOutputPath to avoid colliding with this file
rm -rf "$TARGET_DIR/obj"
touch "$TARGET_DIR/obj"

cd "$TARGET_DIR"
# Containment Rule: Use explicit output paths
# - Output: ../bin/
# - Intermediate: ../obj/ (avoiding the 'obj' file)
dotnet build DeepSeaClient.csproj -c Release --output "../bin/" -p:BaseIntermediateOutputPath="../obj/"

echo "Incubation complete."
