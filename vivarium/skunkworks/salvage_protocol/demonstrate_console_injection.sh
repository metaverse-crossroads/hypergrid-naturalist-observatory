#!/bin/bash
set -e

# DEMONSTRATION: Runtime Console Injection
# This script demonstrates "Technique 1" from the Salvage Protocol Wisdom.
# It sets up a dummy OpenSim configuration to prove how startup_commands.txt works
# without actually launching a heavy OpenSim instance.

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEMO_DIR="$SCRIPT_DIR/demo_workspace"

echo "=========================================================="
echo "Demonstrating: Runtime Console Injection (Salvage Tech 1)"
echo "=========================================================="

mkdir -p "$DEMO_DIR"
cd "$DEMO_DIR"

# 1. Create a dummy OpenSim.ini
echo "[Startup]" > OpenSim.ini
echo "; startup_console_commands_file = \"startup_commands.txt\"" >> OpenSim.ini
echo "DefaultEstateName = My Estate" >> OpenSim.ini

echo "[Step 1] Original OpenSim.ini created."
cat OpenSim.ini

# 2. Apply the Salvage Logic (sed magic)
echo ""
echo "[Step 2] Applying Salvage Injection..."
sed -i 's/; startup_console_commands_file = "startup_commands.txt"/startup_console_commands_file = "startup_commands.txt"/' OpenSim.ini

# 3. Create the Commands File
echo ""
echo "[Step 3] Creating startup_commands.txt..."
cat <<EOF > startup_commands.txt
create user Test User2 password test2@example.com
change region My Estate
alert Hello World from Salvage Protocol
EOF

# 4. Verify
echo ""
echo "[Step 4] Verification:"
echo "--- OpenSim.ini ---"
grep "startup_console_commands_file" OpenSim.ini
echo "--- startup_commands.txt ---"
cat startup_commands.txt

echo ""
echo "SUCCESS: Injection vectors established."
echo "If OpenSim were run in this directory, it would execute these commands on boot."
echo "Cleaning up..."
rm -rf "$DEMO_DIR"
