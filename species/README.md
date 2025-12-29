# Species Protocol

This directory contains the configurations and scripts for acquiring and incubating the various species (simulators and visitants) that populate the Vivarium.

## The Receipts Protocol

**Mandatory Requirement for New Species:**

Any and all new species integrations must strive to support the **Receipts Protocol**. This protocol ensures that the "True Cost of Ownership" (build time, download time, etc.) can be audited.

1.  **Instrument `stopwatch.sh`**: Heavy operations in `acquire.sh` (e.g., git clone, downloading dependencies) and `incubate.sh` (e.g., compilation, building) **must** be wrapped using `instruments/biometrics/stopwatch.sh`.
2.  **Output Directory**: These operations must output their JSON receipts to a `receipts/` directory within the specimen's Vivarium directory (e.g., `vivarium/my-species-1.0/receipts/`).
3.  **Validation**: Verify that running the acquisition and incubation scripts generates the expected JSON files in the `receipts/` directory.

Refer to `instruments/biometrics/README.md` for detailed usage instructions of `stopwatch.sh`.
