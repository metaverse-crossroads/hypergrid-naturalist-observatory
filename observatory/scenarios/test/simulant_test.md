---
Title: Test Simulant Subject
---

# Meta-Test: Simulant Subject

**Purpose:** Verify that `Subject: Simulant` is correctly mapped to the `opensim.log` file in the Observatory directory.

**Prerequisites:**
- The file `vivarium/opensim-core-0.9.3/observatory/opensim.log` must exist.
- It must contain the string "OpenSim".

```verify
Title: Verify Simulant Log Access
Subject: Simulant
Contains: OpenSim
```
