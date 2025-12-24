#!/bin/bash
set -e

# Configuration
SKUNKWORKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1
DAEMON_PY="$SKUNKWORKS_DIR/console_daemon.py"

# Default Credentials (can be overridden)
URL="${OPENSIM_URL:-http://127.0.0.1:9000}"
USER="${OPENSIM_USER:-RestUser}"
PASS="${OPENSIM_PASS:-RestPassword}"

# Check dependencies
if ! command -v python3 &> /dev/null; then
    echo '{"error": "python3 not found"}'
    exit 1
fi

if [ ! -f "$DAEMON_PY" ]; then
    echo '{"error": "console_daemon.py not found"}'
    exit 1
fi

# Execute Daemon
# This script reads from stdin and writes to stdout via the python script
exec python3 "$DAEMON_PY" --url "$URL" --user "$USER" --password "$PASS"
