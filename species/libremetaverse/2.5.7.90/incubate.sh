#!/bin/bash
# species/libremetaverse/2.0.0.278/incubate.sh
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
VIVARIUM_DIR="$REPO_ROOT/vivarium"
SPECIMEN_DIR="$VIVARIUM_DIR/libremetaverse-2.5.7.90"
OBSERVATORY_ENV="$REPO_ROOT/instruments/substrate/observatory_env.bash"
ENSURE_DOTNET="$REPO_ROOT/instruments/substrate/ensure_dotnet.sh"
SRC_FILE="$SCRIPT_DIR/src/DeepSeaClient.cs"
SHARED_SRC_FILE="$REPO_ROOT/species/libremetaverse/src/DeepSeaCommon.cs"

# 1. Prerequisite Check
if [ ! -d "$SPECIMEN_DIR" ]; then
    echo "Specimen not found. Please run acquire.sh first."
    exit 1
fi

echo "Incubating LibreMetaverse (2.5.7.90)..."

# 2. Load Substrate
source "$OBSERVATORY_ENV"
test -v VIVARIUM_DIR || { echo "Error: Environment not set"; exit 1; }

# Verify/Install Dotnet (Idempotent)
"$ENSURE_DOTNET" > /dev/null

echo "Substrate active: $(dotnet --version)"

cd "$SPECIMEN_DIR"

# 3. Clean State Enforcement
# We remove global.json to prevent legacy SDK pinning or incompatibility
rm -f global.json

# Cleanup previous attempts if they exist
rm -rf src/DeepSeaClient* || true

# 4. Preparation: Remove Windows-only projects or legacy artifacts
# LibreMetaverse.GUI and Baker are not present in 2.5.7.90 source structure but we keep the checks safe.
if [ -f "LibreMetaverse.GUI/LibreMetaverse.GUI.csproj" ]; then
    dotnet sln LibreMetaverse.sln remove LibreMetaverse.GUI/LibreMetaverse.GUI.csproj >/dev/null 2>&1 || true
fi

if [ -f "Programs/Baker/Baker.csproj" ]; then
    dotnet sln LibreMetaverse.sln remove Programs/Baker/Baker.csproj >/dev/null 2>&1 || true
fi

# Apply Observatory patch to allow Sdl3Audio to survive missing audio hardware on CI
patch -p1 < "$SCRIPT_DIR/src/Sdl3Audio.patch"
patch -p1 < "$SCRIPT_DIR/src/VoiceSession.patch"

# 5. Preparation: Retarget to .NET 8
# Replaces net9.0, net10.0, net11.0, etc., with net8.0
find . -name "*.csproj" -print0 | xargs -0 sed -i 's/net[1-9]\+\.0/net8.0/g'

# Cleanup: Remove duplicate net8.0;net8.0 that might occur if both existed
find . -name "*.csproj" -print0 | xargs -0 sed -i 's/net8\.0;net8\.0/net8.0/g'

# We also need to downgrade the Roslyn dependencies in SourceGenerators because
# version 4.13.0 requires a newer SDK than our .NET 8 environment provides.
find . -name "*.csproj" -print0 | xargs -0 sed -i 's/Microsoft.CodeAnalysis.CSharp" Version="4.13.0"/Microsoft.CodeAnalysis.CSharp" Version="4.8.0"/g'


# Added the new paths extracted from your error log
for TARGET_DIR in \
  LibreMetaverse.Types \
  LibreMetaverse.LslTools \
  LibreMetaverse.StructuredData \
  LibreMetaverse.Voice.Vivox \
  Programs/examples/PrimInspector \
  Programs/examples/InventoryExplorer \
  Programs/examples/SimpleBot \
  Programs/examples/IRCGateway ; do

    if [ -d "$TARGET_DIR" ]; then
        echo "Staging Directory.Build.props in $TARGET_DIR..."
    cat > $TARGET_DIR/Directory.Build.props <<EOF
    <Project>
    <PropertyGroup>
        <LangVersion>10.0</LangVersion>
        <Nullable>enable</Nullable>
    </PropertyGroup>
    <ItemGroup>
        <!-- dummy package to avoid error MSB4113 -->
        <PackageReference Include="Microsoft.Extensions.Logging" />
    </ItemGroup>
    </Project>
EOF
    else
        echo "Warning: Directory $TARGET_DIR not found, skipping."
    fi
done

# 6. Build LibreMetaverse
echo "Building LibreMetaverse..."
# Ensure no stale assets from previous runs (e.g. if acquire.sh didn't clean enough)
find . -type d \( -name "bin" -o -name "obj" \) -exec rm -rf {} + || true

dotnet restore LibreMetaverse.sln
dotnet build LibreMetaverse.sln -c Release

# 7. Build DeepSeaClient
echo "Building DeepSeaClient..."

# Copy static project and wrapper from source to specimen dir
mkdir -p "$SPECIMEN_DIR/DeepSeaClient_Project"
cp "$SCRIPT_DIR/src/DeepSeaClient.csproj" "$SPECIMEN_DIR/DeepSeaClient_Project/"
cp "$SCRIPT_DIR/src/DeepSeaClient.cs" "$SPECIMEN_DIR/DeepSeaClient_Project/"

cd "$SPECIMEN_DIR/DeepSeaClient_Project"

# Update path to DeepSeaCommon.cs relative to the build location
# The static project has "../../src/DeepSeaCommon.cs"
# We need "../../../species/libremetaverse/src/DeepSeaCommon.cs" to reach out of vivarium back to species
sed -i 's|../../src/DeepSeaCommon.cs|../../../species/libremetaverse/src/DeepSeaCommon.cs|g' DeepSeaClient.csproj

dotnet restore DeepSeaClient.csproj
dotnet build DeepSeaClient.csproj -c Release

echo "Incubation complete."

# Temporary fix: ensure SDL3 native library is copied to output path
# The nuget package restores it to global cache, but occasionally the runtime resolution fails when testing headlessly
echo "Resolving SDL3 dependency for DeepSeaClient..."
SDL3_PKG_DIR=$(find /app/vivarium/substrate/nuget_packages -name "sipsorcerymedia.sdl3.native" -type d | head -n 1 || true)

if [ -n "$SDL3_PKG_DIR" ]; then
    LIB_SDL3=$(find "$SDL3_PKG_DIR" -name "libSDL3.so.0" | grep linux-x64 | head -n 1 || true)
    if [ -n "$LIB_SDL3" ]; then
        echo "Found libSDL3.so at $LIB_SDL3"
        cp "$LIB_SDL3" "$SPECIMEN_DIR/DeepSeaClient_Project/bin/Release/net8.0/libSDL3.so.0"
        cp "$LIB_SDL3" "$SPECIMEN_DIR/DeepSeaClient_Project/bin/Release/net8.0/libSDL3.so"
        cp "$LIB_SDL3" "$SPECIMEN_DIR/DeepSeaClient_Project/bin/Release/net8.0/SDL3.so"
        cp "$LIB_SDL3" "$SPECIMEN_DIR/DeepSeaClient_Project/bin/Release/net8.0/SDL3"
        cp "$LIB_SDL3" "$SPECIMEN_DIR/DeepSeaClient_Project/bin/Release/net8.0/libSDL3"
    fi
fi

# Apply the custom Linux SDL3 build for Observatory testing
if [ -f "$REPO_ROOT/species/libremetaverse/deptest/libSDL3.so.0" ]; then
    echo "Found custom Linux libSDL3.so.0 at $REPO_ROOT/species/libremetaverse/deptest/libSDL3.so.0"
    cp "$REPO_ROOT/species/libremetaverse/deptest/libSDL3.so.0" "$SPECIMEN_DIR/DeepSeaClient_Project/bin/Release/net8.0/libSDL3.so.0"
    cp "$REPO_ROOT/species/libremetaverse/deptest/libSDL3.so.0" "$SPECIMEN_DIR/DeepSeaClient_Project/bin/Release/net8.0/libSDL3.so"
    cp "$REPO_ROOT/species/libremetaverse/deptest/libSDL3.so.0" "$SPECIMEN_DIR/DeepSeaClient_Project/bin/Release/net8.0/SDL3.so"
    cp "$REPO_ROOT/species/libremetaverse/deptest/libSDL3.so.0" "$SPECIMEN_DIR/DeepSeaClient_Project/bin/Release/net8.0/SDL3"
    cp "$REPO_ROOT/species/libremetaverse/deptest/libSDL3.so.0" "$SPECIMEN_DIR/DeepSeaClient_Project/bin/Release/net8.0/libSDL3"
fi
