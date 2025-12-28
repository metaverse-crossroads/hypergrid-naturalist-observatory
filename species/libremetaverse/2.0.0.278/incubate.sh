#!/bin/bash
# species/libremetaverse/2.0.0.278/incubate.sh
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
VIVARIUM_DIR="$REPO_ROOT/vivarium"
SPECIMEN_DIR="$VIVARIUM_DIR/libremetaverse-2.0.0.278"
ENSURE_DOTNET="$REPO_ROOT/instruments/substrate/ensure_dotnet.sh"
SRC_FILE="$SCRIPT_DIR/src/DeepSeaClient.cs"

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

# 3. Clean State Enforcement
# We remove global.json to prevent legacy SDK pinning
rm -f global.json

# Cleanup previous attempts if they exist
rm -rf src/DeepSeaClient* || true

# 4. Preparation: Remove Windows-only projects
# We use 'dotnet sln remove' to keep the SLN file valid
if [ -f "LibreMetaverse.GUI/LibreMetaverse.GUI.csproj" ]; then
    dotnet sln LibreMetaverse.sln remove LibreMetaverse.GUI/LibreMetaverse.GUI.csproj >/dev/null 2>&1 || true
fi

if [ -f "Programs/Baker/Baker.csproj" ]; then
    dotnet sln LibreMetaverse.sln remove Programs/Baker/Baker.csproj >/dev/null 2>&1 || true
fi

# 5. Preparation: Retarget to .NET 8 using Directory.Build.targets
# This is the cleanest way to force all projects to use .NET 8 without editing every csproj.
# We use .targets (imported late) to override values set in the .csproj files.
cat > Directory.Build.targets <<'EOF'
<Project>
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <TargetFrameworks>net8.0</TargetFrameworks>
    <DisableImplicitNuGetFallbackFolder>true</DisableImplicitNuGetFallbackFolder>
    <NoWarn>$(NoWarn);SYSLIB0014;SYSLIB0011;SYSLIB0051;SYSLIB0021;NU1904</NoWarn>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Binaron.Serializer" Version="4.1.0" />
  </ItemGroup>
</Project>
EOF

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
