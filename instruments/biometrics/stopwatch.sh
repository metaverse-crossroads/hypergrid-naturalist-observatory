#!/bin/bash
set -e

# stopwatch.sh
# Usage: stopwatch.sh <output_json> <command> [args...]

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <output_json> <command> [args...]"
    exit 1
fi

OUTPUT_JSON="$1"
shift
CMD="$1"
shift

# Resolve repo root and source environment
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Assuming we are in instruments/biometrics/
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# Source env if it exists (stopwatch might be used generally, but good to link it)
if [ -f "$REPO_ROOT/instruments/substrate/observatory_env.bash" ]; then
    source "$REPO_ROOT/instruments/substrate/observatory_env.bash"
    test -v VIVARIUM_DIR || { echo "Error: Environment not set"; exit 1; }
fi

# Check for date command availability or use python/perl if needed?
# Standard linux date +%s is seconds since epoch.

START_TIME=$(date +%s)
START_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Run the command. We need to preserve exit code.
set +e
"$CMD" "$@"
EXIT_CODE=$?
set -e

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Create directory for receipt if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_JSON")"

# JSON escape helper (minimal)
escape_json_string() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/g' | tr -d '\n'
}

SAFE_CMD=$(escape_json_string "$CMD $*")

# Write JSON
cat > "$OUTPUT_JSON" <<EOF
{
  "timestamp": "$START_ISO",
  "command": "$SAFE_CMD",
  "duration_seconds": $DURATION,
  "exit_code": $EXIT_CODE
}
EOF

exit $EXIT_CODE
