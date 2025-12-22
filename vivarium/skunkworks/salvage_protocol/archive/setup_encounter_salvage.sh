#!/bin/bash
set -e

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
VIVARIUM_DIR="$REPO_ROOT/vivarium"
OPENSIM_DIR="$VIVARIUM_DIR/opensim-core-0.9.3/bin"

echo "======================================================================"
echo "Setup Encounter: Configuration & Population"
echo "======================================================================"

if [ ! -d "$OPENSIM_DIR" ]; then
    echo "Error: OpenSim not found at $OPENSIM_DIR. Please acquire and incubate first."
    exit 1
fi

# 1. Setup Configuration
echo "[SETUP] Configuring OpenSim..."
cd "$OPENSIM_DIR"

# Copy Configs
[ ! -f OpenSim.ini ] && cp OpenSim.ini.example OpenSim.ini
[ ! -f config-include/StandaloneCommon.ini ] && cp config-include/StandaloneCommon.ini.example config-include/StandaloneCommon.ini
[ ! -f Regions/Regions.ini ] && cp Regions/Regions.ini.example Regions/Regions.ini

# Apply Estate Settings (Idempotent sed)
sed -i 's/; DefaultEstateName = My Estate/DefaultEstateName = My Estate/' OpenSim.ini
sed -i 's/; DefaultEstateOwnerName = FirstName LastName/DefaultEstateOwnerName = Test User/' OpenSim.ini
sed -i 's/; DefaultEstateOwnerUUID = .*/DefaultEstateOwnerUUID = 00000000-0000-0000-0000-000000000000/' OpenSim.ini
sed -i 's/; DefaultEstateOwnerEMail = .*/DefaultEstateOwnerEMail = test@example.com/' OpenSim.ini
sed -i 's/; DefaultEstateOwnerPassword = .*/DefaultEstateOwnerPassword = password/' OpenSim.ini

# Populate User 2 via Startup Commands
# OpenSim reads startup_commands.txt on boot if startup_console_commands_file is set.
# Default OpenSim.ini has: ; startup_console_commands_file = "startup_commands.txt"
sed -i 's/; startup_console_commands_file = "startup_commands.txt"/startup_console_commands_file = "startup_commands.txt"/' OpenSim.ini

echo "[SETUP] Creating startup_commands.txt..."
cat <<EOF > startup_commands.txt
create user Test User2 password test2@example.com
change region My Estate
# Note: Rezzing via console is limited. We rely on Mimic to rez objects.
EOF

echo "[SETUP] Configuration Complete."
