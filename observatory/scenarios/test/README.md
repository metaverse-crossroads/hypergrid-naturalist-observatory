# Meta-Testing Scenarios

This directory contains "meta-tests" for the Observatory Director itself. These scenarios are designed to verify the functionality of the `director.py` script, ensuring that the literate markdown parser, sensor subsystem, and environment mappings are working correctly.

## How to Run

You can run these scenarios using the director script from the root of the repository.

### 1. Comment Masking (`test_comment.md`)

Tests that commented-out directives (specifically `[#include]`) are ignored by the parser.

```bash
python3 observatory/director.py observatory/scenarios/test/test_comment.md
```

**Expected Result:** Success (No "Included file not found" error).

### 2. Simulant Subject (`simulant_test.md`)

Tests that `Subject: Simulant` correctly maps to the OpenSim console log.

**Prerequisites:**
You must ensure the log file exists and contains the expected content.
```bash
mkdir -p vivarium/opensim-core-0.9.3/observatory
echo "OpenSim started" > vivarium/opensim-core-0.9.3/observatory/opensim.log
```

**Run:**
```bash
python3 observatory/director.py observatory/scenarios/test/simulant_test.md
```

**Expected Result:** Success (Verification PASSED).

### 3. Async Sensors (`async_test.md`)

Tests the asynchronous log sensor subsystem, specifically the `director#abort` trigger.

**This test requires outside influence.** The scenario waits for a specific log message ("ABORT_NOW") to appear in the Simulant log. If it appears, the director aborts (which counts as a successful test of the abort mechanism, though the director reports "MISSION FAILURE").

**Run:**
```bash
# Start the director in the background
python3 observatory/director.py observatory/scenarios/test/async_test.md &
DIRECTOR_PID=$!

# Wait a moment for sensors to start
sleep 2

# Inject the trigger
echo "ABORT_NOW" >> vivarium/opensim-core-0.9.3/observatory/opensim.log

# Wait for process to exit
wait $DIRECTOR_PID
```

**Expected Result:** The Director should terminate with `[DIRECTOR] SENSOR ABORT: Aborting!`. The final report will show "MISSION FAILURE" because an abort was triggered, but this confirms the sensor works.
