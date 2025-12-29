# Biometrics

This directory contains instruments for the "Forensic Audit Protocol", used to measure the "True Cost of Ownership" of specimens in the Vivarium.

## Instruments

### `stopwatch.sh`
**Usage:** `stopwatch.sh <output_json> <command> [args...]`
Wraps a command to measure its execution time (duration) and exit code. It produces a JSON receipt containing the timestamp, command, duration, and result.

### `meter_substrate.sh`
**Usage:** `meter_substrate.sh <substrate_name>`
Measures the environmental overhead of a substrate (e.g., `rust`, `dotnet`) located in `vivarium/substrate/`. Outputs the human-readable size and file count.

### `generate_invoice.sh`
**Usage:** `generate_invoice.sh <specimen_path> <substrate_name>`
Generates a Markdown-formatted "Invoice" for a specimen. It aggregates:
*   **Environmental Fee:** The cost of the substrate (via `meter_substrate.sh`).
*   **Specimen Mass:** The disk usage of the specimen folder.
*   **Operational Receipts:** A list of operations (e.g., clone, build) captured by `stopwatch.sh`, including total computation time.

## Protocols

### The Receipts Protocol
**Mandatory for all new species integrations.**

Heavy operations (like `git clone`, `cargo fetch`, `pip install`, compilation, building solutions) in species scripts (`acquire.sh`, `incubate.sh`) **must** be wrapped with `stopwatch.sh`. These generate receipts in the specimen's `receipts/` directory (e.g., `vivarium/<species>/receipts/`), which are then audited by `generate_invoice.sh`.

**Implementation Checklist:**
1.  Define `STOPWATCH="$REPO_ROOT/instruments/biometrics/stopwatch.sh"` in your script.
2.  Ensure a `receipts/` directory exists in the target directory.
3.  Wrap long-running commands:
    ```bash
    $STOPWATCH "$RECEIPTS_DIR/build_receipt.json" make build
    ```
4.  Verify that JSON files are created after execution.
