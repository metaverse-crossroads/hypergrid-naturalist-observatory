#!/bin/bash
# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1
# REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
# source "$REPO_ROOT/instruments/substrate/observatory_env.bash"
cat | ${SCRIPT_DIR}/connect_opensim_console_session.sh  | fgrep -v '"event": "connected"' | jq -r '.response // .error // .event // .' 
