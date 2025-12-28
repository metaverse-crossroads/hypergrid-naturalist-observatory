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
SHARED_SRC_FILE="$REPO_ROOT/species/libremetaverse/src/DeepSeaClient.cs"

# 1. Prerequisite Check
if [ ! -d "$SPECIMEN_DIR" ]; then
    echo "Specimen not found. Please run acquire.sh first."
    exit 1
fi

echo "Incubating LibreMetaverse (2.5.7.90)..."

# 2. Load Substrate
source "$OBSERVATORY_ENV"

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

# 5. Preparation: Retarget to .NET 8 by modifying csproj files
# The upstream project targets 'net9.0' which is not available in our substrate.
# We also need to downgrade the Roslyn dependencies in SourceGenerators because
# version 4.13.0 requires a newer SDK than our .NET 8 environment provides.
find . -name "*.csproj" -print0 | xargs -0 sed -i 's/;net9.0//g;s/net9.0;//g'
find . -name "*.csproj" -print0 | xargs -0 sed -i 's/Microsoft.CodeAnalysis.CSharp" Version="4.13.0"/Microsoft.CodeAnalysis.CSharp" Version="4.8.0"/g'

# 6. Build LibreMetaverse
echo "Building LibreMetaverse..."
# Ensure no stale assets from previous runs (e.g. if acquire.sh didn't clean enough)
find . -type d \( -name "bin" -o -name "obj" \) -exec rm -rf {} + || true

dotnet restore LibreMetaverse.sln
dotnet build LibreMetaverse.sln -c Release

# 7. Build DeepSeaClient (Synthetic Project Strategy)
# We generate a separate project file in the build directory to avoid
# polluting the source tree or confusing the 'src/obj' decoy.
echo "Building DeepSeaClient..."
BUILD_DIR="$SPECIMEN_DIR/DeepSeaClient_Build"
mkdir -p "$BUILD_DIR"

cat > "$BUILD_DIR/DeepSeaClient.csproj" <<EOF
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <AssemblyName>DeepSeaClient</AssemblyName>
  </PropertyGroup>

  <ItemGroup>
    <Compile Include="$SRC_FILE" />
    <Compile Include="$SHARED_SRC_FILE" Link="DeepSeaClientShared.cs" />
    <ProjectReference Include="../LibreMetaverse/LibreMetaverse.csproj" />
    <PackageReference Include="System.Configuration.ConfigurationManager" Version="8.0.0" />
    <PackageReference Include="log4net" Version="2.0.15" />
  </ItemGroup>

</Project>
EOF

cd "$BUILD_DIR"
# Restore and Build the client
dotnet restore
dotnet build -c Release

echo "Incubation complete."
