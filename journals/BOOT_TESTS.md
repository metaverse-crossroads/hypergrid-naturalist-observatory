# Boot Tests Protocol

This document records the procedure to verify the operational state of the OpenSim ecosystem from a clean repository state. It serves as a reference for reproducing findings and cross-checking future variants (e.g., `opensim-ngc`).

## 1. Build Verification

**Objective:** Ensure all components compile and install dependencies correctly.

### Commands
```bash
# Build the Visitant (Client)
make mimic

# Build the Territory (Simulator)
make opensim-core
```

### Verification
- `make mimic` output must confirm the creation of `Mimic.dll`.
- `make opensim-core` output must conclude with "Incubation complete" and an invoice generation table.

## 2. Runtime Verification (OpenSim)

**Objective:** Ensure the simulator starts efficiently without stalling, infinite loops, or excessive CPU usage.

### Commands
```bash
# Run OpenSim in the background with a safety timeout (120s) to prevent hangs.
# Output is redirected to a log file for analysis.
timeout 120s make run-opensim-core > opensim_run.log 2>&1 &

# or run interactively...
make run-opensim-core -- -console local
```

### Verification
- **Log File:** `opensim_run.log`
- **Success Criteria:** The log must contain one of the following indicators of a ready state:
  - `[STARTUP]: Startup complete`
  - `LOGINS ENABLED`

## 3. Connectivity Verification (Mimic)

**Objective:** Ensure a client (Visitant) can successfully login and establish a UDP connection to the simulator.

### Commands
Wait for OpenSim to reach the ready state (approx. 10-30 seconds), then run:

```bash
# Run Mimic with default credentials configured in the sandbox estate.
timeout 30s make run-mimic -- --firstname Test --lastname User --password password --uri http://127.0.0.1:9000 > mimic_run.log 2>&1 &
```

### Verification
- **Log File:** `mimic_run.log`
- **Success Criteria:** The log must contain structured JSON events confirming the connection sequence:
  - **Connection:** `"sys": "UDP", "sig": "Connected"`
  - **Login:** `"sys": "Login", "sig": "Success"`

## Notes for Variants

This protocol is polymorphic. To test the `opensim-ngc` variant:
1. Replace `make opensim-core` with `make opensim-ngc`.
2. Replace `make run-opensim-core` with `make run-opensim-ngc`.
3. The connectivity verification steps remain identical.
