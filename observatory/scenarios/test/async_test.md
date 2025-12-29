---
Title: Test Async Sensors
---

# Meta-Test: Async Sensors (Abort)

**Purpose:** Verify that an `async-sensor` can monitor a log file and trigger an abort when a pattern is found.

**Instructions:**
1. Run this scenario.
2. While it is waiting (sleeping), append the string `ABORT_NOW` to the Simulant log (`vivarium/opensim-core-0.9.3/observatory/opensim_console.log`).
3. The Director should detect this and abort immediately.

```async-sensor
Title: Abort Trigger Sensor
Subject: Simulant
Contains: ABORT_NOW
director#abort: Aborting due to external trigger!
```

```wait
10000
```

If the wait completes without aborting, the test has FAILED (the sensor did not fire).
If the director exits early with "SENSOR ABORT", the test has SUCCEEDED (the mechanism works).
