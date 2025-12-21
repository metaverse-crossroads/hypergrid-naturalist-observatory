#!/bin/bash
set -e

# generate_invoice.sh
# Usage: generate_invoice.sh <specimen_path> <substrate_name>

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <specimen_path> <substrate_name>"
    exit 1
fi

SPECIMEN_PATH="$1"
SUBSTRATE_NAME="$2"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
METER_SUBSTRATE="$SCRIPT_DIR/meter_substrate.sh"

if [ ! -d "$SPECIMEN_PATH" ]; then
    echo "Error: Specimen path $SPECIMEN_PATH does not exist."
    exit 1
fi

SPECIMEN_NAME=$(basename "$SPECIMEN_PATH")
RECEIPTS_DIR="$SPECIMEN_PATH/receipts"

# Get Substrate Metrics
SUBSTRATE_OUT=$("$METER_SUBSTRATE" "$SUBSTRATE_NAME")
SUBSTRATE_SIZE=$(echo "$SUBSTRATE_OUT" | grep "Size:" | awk '{print $2}')

# Get Specimen Metrics
SPECIMEN_SIZE=$(du -hs "$SPECIMEN_PATH" | cut -f1)

echo "### Invoice: $SPECIMEN_NAME"
echo ""
echo "| Item | Cost/Size | Details |"
echo "|---|---|---|"
echo "| **Environmental Fee** ($SUBSTRATE_NAME) | $SUBSTRATE_SIZE | Shared Substrate Overhead |"
echo "| **Specimen Mass** | $SPECIMEN_SIZE | Total Disk Usage |"

echo ""
echo "#### Operational Receipts"
echo ""

if [ -d "$RECEIPTS_DIR" ] && [ "$(ls -A "$RECEIPTS_DIR")" ]; then
    echo "| Timestamp | Operation | Duration (s) | Exit Code |"
    echo "|---|---|---|---|"

    for receipt in "$RECEIPTS_DIR"/*.json; do
        # Extract fields using grep/sed/awk to avoid jq dependency if possible, or python
        # Assuming simple JSON structure from stopwatch.sh

        TIMESTAMP=$(grep -o '"timestamp": "[^"]*"' "$receipt" | cut -d'"' -f4)
        CMD=$(grep -o '"command": "[^"]*"' "$receipt" | cut -d'"' -f4 | sed 's/\\\\n//g')
        DURATION=$(grep -o '"duration_seconds": [0-9]*' "$receipt" | awk '{print $2}')
        EXIT_CODE=$(grep -o '"exit_code": [0-9]*' "$receipt" | awk '{print $2}')

        echo "| $TIMESTAMP | \`$CMD\` | ${DURATION}s | $EXIT_CODE |"
    done

    # Calculate Total Time
    TOTAL_TIME=$(grep -o '"duration_seconds": [0-9]*' "$RECEIPTS_DIR"/*.json | awk '{sum+=$2} END {print sum}')
    echo ""
    echo "**Total Computation Tax:** ${TOTAL_TIME}s"
else
    echo "*No receipts found.*"
fi
echo ""
