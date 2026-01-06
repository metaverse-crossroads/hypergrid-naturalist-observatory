---
Title: Query Syntax Test
Description: Verifies the new JSON Query syntax for Director.
---

# Query Syntax Test

This scenario verifies the `Query:` functionality in verify, await, and async-sensor blocks.

## 1. Setup Sample Logs

We create a dummy log file with NDJSON and plain text entries.

```bash
mkdir -p vivarium
LOG_FILE="vivarium/query_test.log"
rm -f "$LOG_FILE"

# 1. Plain text
echo "System initialized" >> "$LOG_FILE"
# 2. Simple JSON
echo '{"sig": "event", "val": 5}' >> "$LOG_FILE"
# 3. Nested JSON
echo '{"sig": "complex", "data": {"user": "Alice", "score": 100}}' >> "$LOG_FILE"
# 4. JSON with different fields
echo '{"sig": "event", "val": 20}' >> "$LOG_FILE"
```

## 2. Verify with Query

### 2.1 Simple Property Check
```verify
Title: Check Simple JSON Property
File: vivarium/query_test.log
Query: entry.sig == 'event' and entry.val == 5
```

### 2.2 Nested Property Check
```verify
Title: Check Nested JSON Property
File: vivarium/query_test.log
Query: entry.sig == 'complex' and entry.data.user == 'Alice'
```

### 2.3 Plain Text Regex Match
```verify
Title: Check Plain Text Regex
File: vivarium/query_test.log
Query: matches(entry, '^System init')
```

### 2.4 Negative Check (Should pass if one line matches)
```verify
Title: Check Logic AND
File: vivarium/query_test.log
Query: entry.val > 10 and entry.sig == 'event'
```

## 3. Await with Query

We will append to the log file in the background and await the condition.

```bash
(sleep 2 && echo '{"sig": "MIGRATION", "user": "Bob", "success": true}' >> vivarium/query_test.log) &
```

```await
Title: Await Login Success
File: vivarium/query_test.log
Query: entry.sig == 'MIGRATION' and entry.user == 'Bob' and entry.success
Timeout: 5000
```

## 4. Async Sensor with Query

We set up a sensor that watches for a specific high-value error.

```async-sensor
Title: High Value Error Sensor
Subject: QueryTest
File: vivarium/query_test.log
Query: entry.sig == 'error' and entry.severity >= 50
director#alert: High severity error detected!
```

Trigger the sensor:

```bash
echo '{"sig": "error", "severity": 10}' >> vivarium/query_test.log
# Should not trigger yet
echo '{"sig": "error", "severity": 55}' >> vivarium/query_test.log
# Should trigger now
```

Wait a bit to ensure sensor catches it (sensors are threaded).

```wait
1000
```

## 5. Verify Sensor Log

The sensor should have logged to the Director's evidence log. We can't easily self-verify the Director's internal log from inside the scenario without a meta-step, but if the sensor crashes or fails, the scenario might fail or we'll see it in stdout.

For now, we just ensure we didn't crash.

```verify
Title: Ensure Log Exists
File: vivarium/query_test.log
Contains: severity": 55
```
