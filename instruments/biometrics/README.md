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
Heavy operations (like `git clone`, `cargo fetch`, compilation) in species scripts (`acquire.sh`, `incubate.sh`) are wrapped with `stopwatch.sh`. These generate receipts in the specimen's `receipts/` directory, which are then audited by `generate_invoice.sh`.
