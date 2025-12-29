#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
VIVARIUM_DIR="$REPO_ROOT/vivarium"
SPECIMEN_DIR="$VIVARIUM_DIR/opensim-core-0.9.3"
OBSERVATORY_ENV="$REPO_ROOT/instruments/substrate/observatory_env.bash"
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
source "$OBSERVATORY_ENV"
test -v VIVARIUM_DIR || { echo "Error: Environment not set"; exit 1; }

# Verify/Install Dotnet (Idempotent)
"$ENSURE_DOTNET" > /dev/null

echo "Substrate active: $(dotnet --version)"

# 3. Patching Strategy: Idempotent & Robust
# Function to apply a patch only if not already applied, and fail if state is messy.
apply_patch_idempotent() {
    local patch_file="$1"
    local patch_name=$(basename "$patch_file")

    # Handle empty glob expansion
    if [ ! -f "$patch_file" ]; then
        return 0
    fi

    echo "Processing patch: $patch_file"

    # Check 1: Is it already applied? (Reverse dry-run)
    # If we can reverse it in dry-run, it means it is fully applied.
    if patch -p1 -R -s -f --dry-run < "$patch_file" > /dev/null 2>&1; then
        echo "  [OK] Patch already applied: $patch_name"
        return 0
    fi

    # Check 2: Is it cleanly applicable? (Forward dry-run)
    if patch -p1 -s -f --dry-run < "$patch_file" > /dev/null 2>&1; then
        echo "  [>>] Applying patch: $patch_name"
        if patch -p1 -s -f < "$patch_file"; then
             echo "  [OK] Successfully applied: $patch_name"
             return 0
        else
             echo "  [!!] Failed to apply patch: $patch_name (Unexpected error)"
             return 1
        fi
    fi

    # Fallback: State is indeterminate.
    echo "  [XX] CRITICAL: Patch state indeterminate for $patch_name"
    echo "       The patch is neither fully applied nor cleanly applicable."
    echo "       This indicates drift, manual modification, or a conflicting patch."

    echo ""
    echo "       --- DEBUG REPORT ---"
    echo "       Patch File: $patch_file"
    echo "       Target Context: $SPECIMEN_DIR"

    echo ""
    echo "       Evidence (Dry-Run Attempts):"
    echo "       1. Reverse (Check if applied): patch -p1 -R -s -f --dry-run < $patch_name"
    if patch -p1 -R -s -f --dry-run < "$patch_file" 2>&1; then echo "          Result: SUCCESS (Should have returned 0 in script logic)"; else echo "          Result: FAILURE"; fi

    echo "       2. Forward (Check if applicable): patch -p1 -s -f --dry-run < $patch_name"
    if patch -p1 -s -f --dry-run < "$patch_file" 2>&1; then echo "          Result: SUCCESS"; else echo "          Result: FAILURE"; fi

    echo ""
    echo "       Target File Analysis:"
    # Extract target files from patch (lines starting with +++)
    # We use awk to be robust against path variations.
    grep "^+++ " "$patch_file" | while read -r line; do
        # Format usually: +++ b/OpenSim/Region/Application/OpenSim.cs
        # Remove "+++ "
        clean_line="${line#+++ }"
        # Remove prefix (b/ or a/) if present.
        # We assume standard git diff format.
        target_file=$(echo "$clean_line" | sed 's/^[ab]\///')

        if [ -f "$target_file" ]; then
            echo "       File: $target_file"
            ls -l "$target_file"

            echo "       Git Status (Local):"
            git status --short "$target_file"

            echo "       Git Diff (Laser-scoped):"
            # Show diff only for this file to reveal modifications
            git diff "$target_file"
        else
            echo "       File: $target_file (NOT FOUND)"
            echo "       Note: File might be new or path logic failed."
        fi
    done

    return 1
}

cd "$SPECIMEN_DIR"

# Apply Fixes
for patch in "$SCRIPT_DIR/patches/fixes"/*.patch; do
    apply_patch_idempotent "$patch"
done

# Apply Instrumentation
for patch in "$SCRIPT_DIR/patches/instrumentation"/*.patch; do
    apply_patch_idempotent "$patch"
done

# 4. Bootstrap Prebuild (Resilience Strategy)
# Always rebuild the tool to ensure it matches current runtime/dependencies.
echo "Bootstrapping Prebuild..."
mkdir -p bin

PROJECT="Prebuild/src/Prebuild.Bootstrap.csproj"
# Always recreate it to ensure it matches our expectations (Idempotency)
cat > "$PROJECT" <<EOF
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <RootNamespace>Prebuild</RootNamespace>
    <AssemblyName>prebuild</AssemblyName>
    <GenerateAssemblyInfo>false</GenerateAssemblyInfo>
    <DefineConstants>TRACE;NETSTANDARD2_0</DefineConstants>
  </PropertyGroup>
</Project>
EOF

# We use 'dotnet build' which handles up-to-date checks correctly.
dotnet build "$PROJECT" -c Release

# Locate and copy the binary
built_dll=$(find Prebuild/src/bin/Release/net8.0 -name "prebuild.dll" | head -n 1)
if [ -n "$built_dll" ]; then
    cp "$built_dll" bin/
    cp "${built_dll%.*}.runtimeconfig.json" bin/ 2>/dev/null || true
else
    echo "Error: Failed to locate built prebuild.dll"
    exit 1
fi

# 5. Generate Solution
echo "Running Prebuild (Solution Generation)..."
# This overwrites OpenSim.sln, which is fine and desired.
"$STOPWATCH" "$RECEIPTS_DIR/prebuild.json" dotnet bin/prebuild.dll /target vs2022 /targetframework net8_0 /excludedir = "obj | bin" /file prebuild.xml

# 6. Build Environment Injection
# We inject Directory.Build.props to force legacy projects to find the local System.Drawing.Common
# which is required for .NET 8 builds of this codebase.
echo "Injecting Directory.Build.props..."
cat > Directory.Build.props <<EOF
<Project>
  <ItemGroup>
    <Reference Include="System.Drawing.Common">
      <HintPath>\$(MSBuildThisFileDirectory)bin/System.Drawing.Common.dll</HintPath>
      <Private>True</Private>
    </Reference>
  </ItemGroup>
</Project>
EOF

# Ensure the DLL is in place
if [ -f "bin/System.Drawing.Common.dll.linux" ]; then
    cp bin/System.Drawing.Common.dll.linux bin/System.Drawing.Common.dll
else
    echo "WARNING: bin/System.Drawing.Common.dll.linux not found. Build may fail."
fi

# 7. Build Solution
echo "Building Solution..."
# dotnet build is incremental.
"$STOPWATCH" "$RECEIPTS_DIR/build_sln.json" dotnet build --configuration Release OpenSim.sln

echo "Incubation complete."
